# Official Timing

Run a variant through the official FlashInfer benchmark path and save exact traces. Choose timing flags from `EVALUATION.md` by exact definition and declared kernel type.

## Inputs

- `variant`: Registered variant id or variant directory path.
- `definition`: Exact contest workload definition.
- `result_dir`: Local dataset/result directory.
- `workloads`: UUIDs, prefixes, workload set, or ordering rule.
- `solution_name`: Local solution name, usually `<variant-id>-local`.

## Evaluation Profiles

Mirror `EVALUATION.md`; re-check it if this table looks stale.

| Track | Definition | Category | Extra Timing Flags | Track Kernel Count |
|---|---|---|---|---:|
| MoE | `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` | `moe` | `--atol 1 --rtol 0.3 --required-matched-ratio 0.9` | 1 |
| DSA Attention | `dsa_sparse_attention_h16_ckv512_kpe64_topk2048_ps64` | `dsa_paged` | none | 2 |
| DSA Indexer | `dsa_topk_indexer_fp8_h64_d128_topk2048_ps64` | `dsa_paged` | none | 2 |
| GDN Decode | `gdn_decode_qk4_v8_d128_k_last` | `gdn` | none | 2 |
| GDN Prefill | `gdn_prefill_qk4_v8_d128_k_last` | `gdn` | `--warmup-runs 1 --iterations 5 --num-trials 3` | 2 |

## Steps

1. Resolve `definition` from variant metadata, config, or user input.
2. Select the evaluation profile for that definition.
3. Discover dataset source with `project-cli`.
4. Confirm `<category>` from `<dataset-root>/definitions/<category>/<definition>.json`.
5. Create `<result-dir>` with matching `definitions`, `workloads`, `solutions`, and `blob` layout.
6. Write selected workload records in requested order.
7. Pack variant JSON into `<result-dir>/solutions/local/<category>/<definition>/`.
8. Run common official flags plus profile-specific flags.
9. Parse `<result-dir>/traces/<category>/<definition>.jsonl`.
10. Report command, GPU, profile, workload rule, and exact results.

## Discover Source

```bash
pixi run project-cli workload source list
pixi run project-cli workload source show <source-name>
pixi run project-cli workload list --source <source-name> --definition <definition> --limit 5
find <dataset-root>/definitions -mindepth 2 -maxdepth 2 -name '<definition>.json' -print
```

Use the reported source path as `<dataset-root>`. Confirm `<category>` against the selected evaluation profile.

## Create Local Dataset

```bash
mkdir -p <result-dir>/definitions/<category> <result-dir>/workloads/<category> <result-dir>/solutions/local/<category>/<definition>
cp <dataset-root>/definitions/<category>/<definition>.json <result-dir>/definitions/<category>/<definition>.json
ln -sfn <relative-or-absolute-path-to-dataset-root>/blob <result-dir>/blob
```

Write `<result-dir>/workloads/<category>/<definition>.jsonl` from `<dataset-root>/workloads/<category>/<definition>.jsonl`. Preserve requested order. Report all useful workload axes.

## Pack Variant

- Registered id:
  `pixi run -e cu130 python skillset/runtime/project-op-variant-profiling/scripts/pack_variant_solution.py --variant <variant-id> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json`
- Directory path:
  `pixi run -e cu130 python skillset/runtime/project-op-variant-profiling/scripts/pack_variant_solution.py --path <variant-dir> --definition <definition> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json`

## Run Timing

Use Pixi-provided CUDA and libraries first. For local replay, keep `--solutions <solution-name>` to isolate the packed variant. Omit it only when intentionally reproducing an all-solutions dataset run.

```bash
CUDA_VISIBLE_DEVICES=<gpu> \
pixi run -e cu130 flashinfer-bench run --local <result-dir> \
  --definitions <definition> \
  --solutions <solution-name> \
  --save-results --use-isolated-runner --log-level INFO --resume --timeout 300 \
  <extra-timing-flags-from-profile>
```

If library lookup fails, discover paths from the active environment and record the final command:

```bash
pixi run -e cu130 bash -lc 'echo CUDA_HOME=$CUDA_HOME; command -v nvcc; python - <<PY
import site
print("\\n".join(site.getsitepackages()))
PY'
```

## Parse Results

```bash
python - <<'PY'
import json
from pathlib import Path

category = "<category>"
definition = "<definition>"
trace = Path("<result-dir>") / "traces" / category / f"{definition}.jsonl"
print("| axes | uuid | solution | status | latency_ms | reference_ms | speedup | matched_ratio |")
print("|---|---|---|---|---:|---:|---:|---:|")
for line in trace.read_text().splitlines():
    row = json.loads(line)
    ev = row["evaluation"]
    perf = ev.get("performance") or {}
    corr = ev.get("correctness") or {}
    extra = corr.get("extra") or {}
    workload = row["workload"]
    axes = ",".join(f"{k}={v}" for k, v in sorted((workload.get("axes") or {}).items()))
    def fmt(value):
        return "" if value is None else f"{value:.6f}"
    print(f"| {axes} | {workload['uuid']} | {row['solution']} | {ev['status']} | {fmt(perf.get('latency_ms'))} | {fmt(perf.get('reference_latency_ms'))} | {fmt(perf.get('speedup_factor'))} | {fmt(extra.get('matched_ratio'))} |")
PY
```

## Report

- Repro: Exact command, GPU id, result directory, dataset root, category, evaluation profile.
- Workloads: Selection rule, UUIDs, axes.
- Results: Status, latency, reference latency, speedup, correctness extras.
- Track context: Track kernel count; DSA/GDN track scores expect both definitions.
- Failures: Timeout and compile errors as first-class results.
