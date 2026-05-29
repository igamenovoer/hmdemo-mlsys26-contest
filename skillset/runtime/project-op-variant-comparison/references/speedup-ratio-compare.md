# Speedup Ratio Compare

Compare two variants by official FlashInfer-Bench speedup ratio. This is the preferred contest-facing signal because it uses `official-timing` and reports the speedup surface expected by the MLSys 2026 FlashInfer contest flow.

## Inputs

- `variant_a`: Registered variant id or variant directory path.
- `variant_b`: Registered variant id or variant directory path.
- `definition`: Exact contest workload definition; infer only when both variants declare the same definition.
- `workloads`: UUIDs, prefixes, workload set, or axis filter. Default to all available local workloads for the definition when practical.
- `result_dir`: Directory for both official timing datasets, traces, logs, and comparison summary.
- `gpu`: Physical GPU id. Choose an idle GPU and use the same id for both variants.

## Procedure

1. Load `project-op-variant-profiling` and use `official-timing`.
2. Resolve both variants and confirm they target the same exact definition.
3. Resolve workload scope. Default to all workloads, but use a user-provided subset or representative subset when requested.
4. Create matched local datasets for both variants with the same workload records in the same order.
5. Pack each variant as a separate local solution name.
6. Run FlashInfer-Bench timing for both variants on the same GPU with identical official flags for the definition.
7. Parse each trace for status, latency, reference latency, speedup factor, and correctness extras.
8. Compare per-workload speedup factors first, then summarize the aggregate pattern.

## Comparison Metric

Use the official `speedup_factor` emitted in the trace:

```text
ratio_a_over_b = speedup_factor_a / speedup_factor_b
```

Values above `1.0` mean A is better by official speedup ratio. Values below `1.0` mean B is better by official speedup ratio.

Do not compare failed or incorrect rows as performance wins. Surface them as validity failures.

## Pros And Cons

- Pros: Closer to the MLSys 2026 FlashInfer contest standard because it uses the official benchmark path and speedup reporting.
- Pros: Includes correctness and evaluator-specific constraints in the same run, so an invalid fast variant is not mistaken for a valid performance win.
- Pros: Useful when reporting expected contest impact or deciding which variant to submit.
- Cons: Less clean as an A/B kernel timing signal because each result is mediated through the official baseline/reference behavior and FlashInfer-Bench timing configuration.
- Cons: Measurement variance is less explicit than NVBench latency comparison unless repeated runs are performed manually.
- Cons: More heavyweight than NVBench direct timing and may be slower when iterating across many variants.

## Report Shape

```text
Comparison: speedup-ratio-compare
Definition: <definition>
GPU: <id> <name>
Workload scope: <selection rule>
Official profile: <definition-specific flags>

| workload | axes | A status | A speedup | B status | B speedup | A/B official ratio |
|---|---|---|---:|---|---:|---:|

Summary: <A better / B better / similar / inconclusive>, with workload exceptions and failures.
Artifacts: A=<trace/log/solution>, B=<trace/log/solution>
```
