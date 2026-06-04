---
name: project-op-variant-validation
description: Project operation skill for checking whether MLSys FlashInfer contest kernel variants are valid kernels by registered variant id or variant directory path. Use when Codex needs to run FlashInfer-Bench correctness validation, compile/runtime/shape/dtype/numerical checks, MoE matched-ratio checks, or a cheap multi-trial validity gate before timing or profiling.
---

# Project Op Variant Validation

Use from the repository root. This skill answers one question: can this kernel variant compile and produce correct outputs for the selected FlashInfer contest workload(s)?

Validation uses FlashInfer-Bench because it owns reference generation and evaluator-specific correctness checks. It intentionally does not reason about timing noise or speedup stability.

## Commands

- `official-correctness-check`: Check variant compile/runtime/shape/dtype/numerical validity with FlashInfer-Bench. Load `references/official-correctness-check.md`.

## Shared Rules

- Resolve the exact definition from variant metadata, `configs/variants.toml`, or user input before running.
- Use a local FlashInfer trace dataset; prefer the `contest-local` workload source when available.
- Pack variant id/path directly with this skill's script; do not deploy into `solution/cuda/` just to validate.
- Use at least `--num-trials 5`; trials create independent input/reference sets for randomized validation coverage.
- Keep timing cheap, usually `--warmup-runs 0 --iterations 1`; timing values are incidental validation byproducts.
- Avoid `--resume` by default so stale passing traces cannot hide a newly broken variant.
- Save dataset slices, packed solution JSONs, traces, and logs under the requested result directory.

## Tool Probes

- FlashInfer-Bench: `pixi run -e cu130 bash -lc 'command -v flashinfer-bench; flashinfer-bench run --help | head -40'`
- Workload source: `pixi run project-cli workload source list`
- Workload examples: `pixi run project-cli workload list --source contest-local --definition <definition> --limit 5`
- GPU state: `nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits`

## Pack Variant

- Registered id:
  `pixi run -e cu130 python skillset/runtime/project-op-variant-validation/scripts/pack_variant_solution.py --variant <variant-id> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json`
- Directory path:
  `pixi run -e cu130 python skillset/runtime/project-op-variant-validation/scripts/pack_variant_solution.py --path <variant-dir> --definition <definition> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json`

## Result Meaning

| Status | Meaning |
|---|---|
| `PASSED` | Variant compiled, ran, and passed evaluator correctness for selected workloads/trials. |
| `COMPILE_ERROR` | Build failed; inspect worker log path recorded in the trace. |
| `RUNTIME_ERROR` / `TIMEOUT` | Kernel or runner failed at execution time. |
| `INCORRECT_SHAPE` / `INCORRECT_DTYPE` | Output contract mismatch. |
| `INCORRECT_NUMERICAL` | Numerical tolerance or evaluator-specific validity failed. |

For performance or speedup claims, use `project-op-variant-profiling`. For independent kernel latency only, use that skill's `nvbench-timing`.
