# Official Correctness Check

Run a variant through FlashInfer-Bench as a cheap validity gate. This confirms that the kernel can compile, run, and produce correct results for selected workloads. It does not establish stable latency or speedup.

## Inputs

- `variant`: Registered variant id or variant directory path.
- `definition`: Exact contest workload definition. Infer from variant metadata when possible.
- `result_dir`: Validation dataset/result directory.
- `workloads`: UUIDs, prefixes, workload set, or a small selection rule.
- `solution_name`: Local solution name, usually `<variant-id>-validation`.

## Validation Profiles

Mirror evaluator tolerances from `EVALUATION.md`, but force enough randomized trials for validation coverage.

| Track | Definition | Category | Correctness Flags |
|---|---|---|---|
| MoE | `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` | `moe` | `--atol 1 --rtol 0.3 --required-matched-ratio 0.9 --num-trials 5` |
| DSA Attention | `dsa_sparse_attention_h16_ckv512_kpe64_topk2048_ps64` | `dsa_paged` | `--num-trials 5` |
| DSA Indexer | `dsa_topk_indexer_fp8_h64_d128_topk2048_ps64` | `dsa_paged` | `--num-trials 5` |
| GDN Decode | `gdn_decode_qk4_v8_d128_k_last` | `gdn` | `--num-trials 5` |
| GDN Prefill | `gdn_prefill_qk4_v8_d128_k_last` | `gdn` | `--num-trials 5` |

Use `--warmup-runs 0 --iterations 1` for this check unless the user explicitly wants a timing-quality run. FlashInfer-Bench still performs minimal timing after correctness passes; ignore those performance fields for validity decisions.

## Workflow

1. Resolve `definition`, `<category>`, and variant kernel path.
2. Discover a local dataset source and inspect a few workloads.
3. Choose at least one representative workload; use more when a bug may be axis-specific.
4. Create a local result dataset containing only selected workloads.
5. Pack the variant solution JSON into the local result dataset.
6. Run `flashinfer-bench run` with `--solutions <solution-name>`, validation profile flags, `--num-trials 5`, and cheap timing flags.
7. Parse traces for status and correctness fields; treat failures as first-class results.

## Discover Source

```bash
pixi run project-cli workload source list
pixi run project-cli workload source show <source-name>
pixi run project-cli workload list --source <source-name> --definition <definition> --limit 5
find <dataset-root>/definitions -mindepth 2 -maxdepth 2 -name '<definition>.json' -print
```

Confirm `<category>` from the dataset path: `<dataset-root>/definitions/<category>/<definition>.json`.

## Create Local Dataset

```bash
mkdir -p <result-dir>/definitions/<category> <result-dir>/workloads/<category> <result-dir>/solutions/local/<category>/<definition>
cp <dataset-root>/definitions/<category>/<definition>.json <result-dir>/definitions/<category>/<definition>.json
ln -sfn <relative-or-absolute-path-to-dataset-root>/blob <result-dir>/blob
```

Write `<result-dir>/workloads/<category>/<definition>.jsonl` from the source workload JSONL, preserving only the selected workload records and requested order. Report UUIDs and axes.

## Pack Variant

```bash
pixi run -e cu130 python skillset/runtime/project-op-variant-validation/scripts/pack_variant_solution.py \
  --variant <variant-id> \
  --name <solution-name> \
  --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json
```

For a directory path:

```bash
pixi run -e cu130 python skillset/runtime/project-op-variant-validation/scripts/pack_variant_solution.py \
  --path <variant-dir> \
  --definition <definition> \
  --name <solution-name> \
  --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json
```

## Run Check

Use Pixi-provided CUDA and libraries first. Do not pass `--resume` unless intentionally reusing a frozen result directory.

```bash
CUDA_VISIBLE_DEVICES=<gpu> \
pixi run -e cu130 flashinfer-bench run --local <result-dir> \
  --definitions <definition> \
  --solutions <solution-name> \
  --save-results --use-isolated-runner --log-level INFO --timeout 300 \
  --warmup-runs 0 --iterations 1 \
  <correctness-flags-from-profile>
```

For MoE this becomes:

```bash
CUDA_VISIBLE_DEVICES=<gpu> \
pixi run -e cu130 flashinfer-bench run --local <result-dir> \
  --definitions moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --solutions <solution-name> \
  --save-results --use-isolated-runner --log-level INFO --timeout 300 \
  --warmup-runs 0 --iterations 1 --num-trials 5 \
  --atol 1 --rtol 0.3 --required-matched-ratio 0.9
```

## Parse Results

```bash
python - <<'PY'
import json
from pathlib import Path

category = "<category>"
definition = "<definition>"
trace = Path("<result-dir>") / "traces" / category / f"{definition}.jsonl"
print("| axes | uuid | solution | status | max_abs | max_rel | matched_ratio | log |")
print("|---|---|---|---|---:|---:|---:|---|")
for line in trace.read_text().splitlines():
    row = json.loads(line)
    ev = row["evaluation"]
    corr = ev.get("correctness") or {}
    extra = corr.get("extra") or {}
    workload = row["workload"]
    axes = ",".join(f"{k}={v}" for k, v in sorted((workload.get("axes") or {}).items()))
    def fmt(value):
        return "" if value is None else f"{value:.6g}"
    print(
        f"| {axes} | {workload['uuid']} | {row['solution']} | {ev['status']} | "
        f"{fmt(corr.get('max_absolute_error'))} | {fmt(corr.get('max_relative_error'))} | "
        f"{fmt(extra.get('matched_ratio'))} | {ev.get('log') or ''} |"
    )
PY
```

## Report

- Verdict: Valid only if every selected trace has `status == PASSED`.
- Repro: Exact command, GPU id, result directory, dataset root, definition, category.
- Workloads: Selection rule, UUIDs, axes.
- Correctness: Max absolute/relative error and evaluator extras such as MoE `matched_ratio`.
- Failures: Compile/runtime/timeout/shape/dtype/numerical status and log path.
- Caveat: Timing output is incidental; run profiling for latency claims.

If a variant passes one small workload, phrase the result narrowly: "valid for selected workload(s)." Broaden only after checking the requested workload set.
