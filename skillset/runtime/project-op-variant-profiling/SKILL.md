---
name: project-op-variant-profiling
description: Project operation skill for setting up, timing, and launching MLSys FlashInfer contest kernel variants by registered variant id or variant directory path. Use when Codex needs `official-timing` for correctness/speedup timing, `nvbench-timing` for timing a CUDA variant directly through the repo C++ NVBench profiler, a local trace dataset and packed solution, `ncu-inspect` setup for Nsight Compute, reproducible result artifacts, or a handoff to `krnopt-cuda-profiling` for detailed NCU/NSYS interpretation.
---

# Project Op Variant Profiling

Use from the repository root. This skill owns project setup and artifact flow; `skillset/runtime/krnopt-cuda-profiling` owns NCU/NSYS counter choice, interpretation, bottleneck classification, and profiler-to-source attribution.

## Commands

- `official-timing`: Run official correctness, latency, and speedup timing for a variant. Load `references/official-timing.md`.
- `nvbench-timing`: Time a CUDA variant directly with `cpp/` NVBench profiler, independent of FlashInfer-Bench correctness/reference comparison. Currently covers MoE only. Load `references/nvbench-timing.md`.
- `ncu-inspect`: Run an already packed/timed variant under NCU and save profiler artifacts. Load `references/ncu-inspect.md`.

## Shared Rules

- Resolve workload scope from the exact definition, variant/config declarations, and dataset category.
- Use Pixi first and verify tool resolution; fall back to explicit discovered paths only when needed.
- Check `nvidia-smi`; use only an idle GPU with enough VRAM.
- Prefer packing variant id/path directly; do not deploy into `solution/cuda/` just to profile.
- Prefer the C++ profiler for independent NVBench timing only; it does not compute correctness, reference latency, or speedup.
- Save datasets, solution JSONs, logs, traces, and profiler reports under the requested result directory.
- After NCU artifacts exist, route only to `krnopt-cuda-profiling` for profiler analysis.

## Tool Probes

- Benchmark tools: `pixi run -e cu130 bash -lc 'command -v flashinfer-bench; command -v nvcc'`
- NCU/NSYS in Pixi: `pixi run -e cu130 bash -lc 'command -v ncu || true; command -v nsys || true'`
- NCU/NSYS on host: `command -v ncu || true; command -v nsys || true`
- GPU state: `nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits`

## Pack Variant

- Registered id:
  `pixi run -e cu130 python skillset/runtime/project-op-variant-profiling/scripts/pack_variant_solution.py --variant <variant-id> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json`
- Directory path:
  `pixi run -e cu130 python skillset/runtime/project-op-variant-profiling/scripts/pack_variant_solution.py --path <variant-dir> --definition <definition> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json`

## Handoff

- After `official-timing`: Use `ncu-inspect` only when a performance claim needs profiler support.
- After `ncu-inspect`: Load `krnopt-cuda-profiling` with report paths and the exact NCU command.

Do not rely on old logs if solution JSONs or variant files changed after the log timestamp; replay the requested workload order with `official-timing`.
