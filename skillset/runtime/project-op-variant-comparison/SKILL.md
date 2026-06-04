---
name: project-op-variant-comparison
description: Project operation skill for comparing MLSys FlashInfer contest kernel variants against each other by registered variant id or variant directory path. Use when Codex needs to decide whether one variant is faster or slower than another using `latency-compare` with the C++ NVBench profiler, or `speedup-ratio-compare` with official FlashInfer-Bench speedup ratios.
---

# Project Op Variant Comparison

Use from the repository root. This skill answers one question: which kernel variant is faster for the selected workload scope?

This skill coordinates measurements by delegating timing execution to `project-op-variant-profiling`. It does not validate kernel correctness by itself; run `project-op-variant-validation` first when either variant has not already passed correctness for the same definition/workloads.

## Commands

- `latency-compare`: Time two variants with `project-op-variant-profiling` `nvbench-timing` on the same GPU and selected workload(s), then compare latency with NVBench sample/noise context. Load `references/latency-compare.md`.
- `speedup-ratio-compare`: Time two variants with `project-op-variant-profiling` `official-timing`, then compare FlashInfer-Bench speedup ratios. Load `references/speedup-ratio-compare.md`.

## Choosing A Comparison

- Prefer `latency-compare` when the goal is to decide whether one variant is materially faster or slower than another under controlled local conditions. It uses NVBench semantics and can account for measurement variance through samples, noise, and stopping criteria.
- Prefer `speedup-ratio-compare` when the goal is to match the MLSys 2026 FlashInfer contest scoring surface. It is closer to contest-standard reporting because it compares official speedup ratios against the benchmark reference/baseline behavior.
- Use both when a claim will guide optimization direction: `latency-compare` for the cleaner A/B signal, `speedup-ratio-compare` for contest-facing confidence.

## Shared Rules

- Resolve both variants to the same exact definition before comparing. Stop if the definitions differ unless the user explicitly asks for cross-definition reporting rather than faster/slower comparison.
- Default workload scope to all available local workloads for the definition. Narrow the scope when the user, prompt, context, or time budget specifies workload UUIDs, prefixes, workload sets, or representative axes.
- Run both variants on the same physical GPU in the same session window. Check `nvidia-smi` before and after; report GPU id/name and any contention.
- Keep timing configuration identical across variants for the selected comparison mode.
- Save per-variant logs, JSON/traces, and the final comparison summary under the requested result directory.
- Treat compile/runtime/correctness failures as comparison results, not missing data.
- Do not average across unlike workload axes without also reporting per-workload results.

## Result Language

- Say `faster` only when the measured difference is larger than the relevant noise/uncertainty for that mode.
- Say `similar` or `inconclusive` when confidence intervals/noise overlap, sample counts are too small, workloads disagree, or one run is visibly contaminated.
- Report direction per workload first, then summarize the aggregate pattern.

## Handoff

- For timing execution details, load `project-op-variant-profiling` and its relevant subskill.
- For correctness validity, load `project-op-variant-validation`.
- For profiler-counter explanations after a latency gap is found, hand off to `krnopt-cuda-profiling`.
