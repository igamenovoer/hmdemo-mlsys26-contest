# Latency Compare

Compare two variants by direct GPU latency using the C++ NVBench profiler. This is the preferred local A/B signal for whether one kernel is faster or slower because both variants can be timed with the same NVBench stopping criterion, sample count, runtime variance threshold, workload data, runner, and GPU.

## Inputs

- `variant_a`: Registered variant id or variant directory path.
- `variant_b`: Registered variant id or variant directory path.
- `definition`: Exact contest workload definition; infer only when both variants declare the same definition.
- `workloads`: UUIDs, prefixes, workload set, or axis filter. Default to all available local workloads for the definition when practical.
- `result_dir`: Directory for both variants' profiler artifacts and comparison summary.
- `gpu`: Physical GPU id. Choose an idle GPU and use the same id for both variants.

## Procedure

1. Load `project-op-variant-profiling` and use `nvbench-timing`.
2. Resolve both variants and confirm they target the same supported kernel type. Currently the C++ NVBench profiler covers MoE only.
3. Resolve workload scope. Default to all workloads, but use a user-provided subset or representative subset when requested.
4. Probe GPU state and choose one idle GPU.
5. Build or reuse one static `hm-nvbench-runner` for the session.
6. Build one plugin artifact per variant. Runtime workload choices and timing options should not change artifact identity.
7. Run every selected workload for both variants with identical NVBench options and the same `CUDA_VISIBLE_DEVICES=<gpu>`.
8. Parse each NVBench JSON for mean GPU latency, relative GPU noise, and sample count.
9. Compare per workload. Use the slower/faster ratio and noise bands to classify the result.
10. Summarize the aggregate pattern without hiding workload-level disagreements.

## Timing Defaults

Use sample-count mode for a quick comparison:

```bash
--cold-warmup-runs 1 --stopping-criterion sample-count --min-samples 10 --target-samples 20 --timeout 300 --devices 0
```

Use convergence mode when the decision is close:

```bash
--cold-warmup-runs 1 --stopping-criterion stdrel --min-samples 10 --max-noise 0.5 --min-time 0.2 --timeout 300 --devices 0
```

Keep all timing options identical for both variants. Prefer convergence mode when the observed difference is within roughly twice the reported relative GPU noise.

## Classification

- `A faster`: `latency_a < latency_b` and the relative gap is clearly larger than both runs' reported noise.
- `B faster`: `latency_b < latency_a` and the relative gap is clearly larger than both runs' reported noise.
- `similar`: the gap is small relative to reported noise or varies without a stable pattern.
- `inconclusive`: missing data, insufficient samples, GPU contention, run failures, or workload disagreement prevents a clear direction.

Use this ratio for each workload:

```text
speedup_a_over_b = latency_b_ms / latency_a_ms
```

Values above `1.0` mean A is faster than B. Values below `1.0` mean A is slower than B.

## Pros And Cons

- Pros: Directly compares the two variant kernels under the same local profiler; handles measurement variance explicitly; avoids baseline/reference effects when the question is only A versus B.
- Pros: Reuses the static C++ runner and per-kernel plugin flow, so compiling a new variant does not rebuild NVBench.
- Cons: NVBench timing is independent of FlashInfer-Bench correctness and contest scoring; a faster result is not a valid contest result unless correctness is checked separately.
- Cons: Current C++ profiler support is narrower than FlashInfer-Bench and currently covers MoE only.
- Cons: Input materialization may not exactly match FlashInfer-Bench unless the profiler/workload path has been aligned for the target definition.

## Report Shape

```text
Comparison: latency-compare
Definition: <definition>
GPU: <id> <name>
Workload scope: <selection rule>
NVBench: <stopping criterion>, <samples/noise settings>

| workload | axes | A latency ms | A noise % | B latency ms | B noise % | A/B result |
|---|---|---:|---:|---:|---:|---|

Summary: <A faster / B faster / similar / inconclusive>, with workload exceptions.
Artifacts: A=<dir-or-jsons>, B=<dir-or-jsons>, runner=<path>
Correctness: <known status or not checked by NVBench>
```
