---
name: project-op-variant-profiling
description: Project operation skill for setting up, timing, and launching MLSys FlashInfer contest kernel variants by registered variant id or variant directory path. Use when Codex needs `official-timing` for any contest workload definition, a local trace dataset and packed solution, `ncu-inspect` setup for Nsight Compute, reproducible result artifacts, or a handoff to `krnopt-cuda-profiling` for detailed NCU/NSYS interpretation.
---

# Project Op Variant Profiling

Use from the repository root. This skill owns project setup and artifact flow; `skillset/runtime/krnopt-cuda-profiling` owns NCU/NSYS counter choice, interpretation, bottleneck classification, and profiler-to-source attribution.

## Commands

| Command | Use When | Load |
|---|---|---|
| `official-timing` | Run official correctness, latency, and speedup timing for a variant. | `references/official-timing.md` |
| `ncu-inspect` | Run an already packed/timed variant under NCU and save profiler artifacts. | `references/ncu-inspect.md` |

## Shared Rules

| Rule | Guidance |
|---|---|
| Workload scope | Resolve kernel type from the exact definition, variant/config declarations, and dataset category. |
| Tool lookup | Use Pixi first and verify resolution; fall back to explicit discovered paths only when needed. |
| GPU use | Check `nvidia-smi`; use only an idle GPU with enough VRAM. |
| Variant packing | Prefer packing variant id/path directly; do not deploy into `solution/cuda/` just to profile. |
| Results | Save datasets, solution JSONs, logs, traces, and profiler reports under the requested result directory. |
| Handoff | After NCU artifacts exist, route only to `krnopt-cuda-profiling` for profiler analysis. |

## Tool Probes

| Need | Probe |
|---|---|
| Benchmark tools | `pixi run -e cu130 bash -lc 'command -v flashinfer-bench; command -v nvcc'` |
| NCU/NSYS in Pixi | `pixi run -e cu130 bash -lc 'command -v ncu || true; command -v nsys || true'` |
| NCU/NSYS on host | `command -v ncu || true; command -v nsys || true` |
| GPU state | `nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits` |

## Pack Variant

| Input | Command |
|---|---|
| Registered id | `pixi run -e cu130 python skillset/runtime/project-op-variant-profiling/scripts/pack_variant_solution.py --variant <variant-id> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json` |
| Directory path | `pixi run -e cu130 python skillset/runtime/project-op-variant-profiling/scripts/pack_variant_solution.py --path <variant-dir> --definition <definition> --name <solution-name> --output <result-dir>/solutions/local/<category>/<definition>/<solution-name>.json` |

## Handoff

| After | Do |
|---|---|
| `official-timing` | Use `ncu-inspect` only when a performance claim needs profiler support. |
| `ncu-inspect` | Load `krnopt-cuda-profiling` with report paths and the exact NCU command. |

Do not rely on old logs if solution JSONs or variant files changed after the log timestamp; replay the requested workload order with `official-timing`.
