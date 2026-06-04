## Context

The C++ profiler is a local NVBench timing tool, not an evaluator-compatible replacement for FlashInfer-Bench. Earlier design work intentionally separated artifact compilation from workload profiling and added NVBench stopping controls, but the `run` command still accepts FlashInfer-Bench-style aliases such as `--iterations`, `--warmup-runs`, `--num-trials`, and correctness options that are parsed only to reject. This creates an ambiguous interface: measurement options look partly like FlashInfer-Bench while the underlying runner is NVBench.

The intended direction is to make the profiler independent and NVBench-native. Workload and artifact selection remain project-specific; measurement and output controls should use NVBench names and behavior whenever NVBench has an equivalent.

## Goals / Non-Goals

**Goals:**
- Make the C++ profiler `run` CLI prefer NVBench option names and semantics for measurement, device selection, output, and stopping criteria.
- Remove or replace FlashInfer-Bench compatibility aliases when they overlap with NVBench controls.
- Keep the CLI small by avoiding correctness-only options and artificial trial concepts that are not native to NVBench.
- Preserve artifact reuse: timing and output options remain runtime-only inputs.
- Update docs and tests so the intended CLI contract is explicit.

**Non-Goals:**
- Do not change `flashinfer-bench`, `pixi run bench`, Modal benchmark, packing, or project variant workflows.
- Do not change the profiler build command or artifact manifest schema except where docs mention runtime-only options.
- Do not implement correctness checking or reference comparisons in C++.
- Do not expose every NVBench option in this change; focus on the current overlap and common timing controls.

## Decisions

1. Measurement options use NVBench names. Replace `--warmup-runs` with `--cold-warmup-runs`, replace `--device` with `--devices`, and remove `--iterations` in favor of `--min-samples` and `--target-samples`. The profiler should forward those options to NVBench with minimal translation.

2. Remove FlashInfer-Bench correctness options from the C++ profiler. `--rtol`, `--atol`, and `--required-matched-ratio` should no longer appear in help or be specially parsed. Passing them should fail as unknown CLI options. This makes it clear the profiler is timing-only rather than evaluation-compatible.

3. Remove `--num-trials` from the profiler CLI. The current implementation repeats workload entries to simulate trials, but NVBench already gathers multiple samples under its stopping criteria. Artificial trial repetition is a FlashInfer-Bench-ish concept and can distort workload identity in NVBench output.

4. Remove or defer `--random-seed` unless true random materialization is implemented. The current generated runner fills random tensors deterministically with a fixed byte pattern, so a seed option suggests behavior that does not exist. If deterministic generated random inputs become useful later, add an explicit NVBench-profiler runtime data generation requirement.

5. Keep profiler-specific selectors. Options such as `--artifact`, `--local`, `--definition`, `--workload`, and `--workload-set` have no NVBench equivalent because they describe the project-specific artifact and FlashInfer Trace workload context.

6. Keep NVBench stopping and output controls. `--stopping-criterion`, `--min-samples`, `--target-samples`, `--max-noise`, `--min-time`, `--timeout`, `--json`, `--csv`, and `--markdown` remain supported. This change may add entropy parameters such as `--max-angle` and `--min-r2` only if implementation cost is low and tests can cover validation.

## Risks / Trade-offs

- Existing local commands using compatibility aliases break → Mitigation: document direct replacements and make the change explicit as breaking in the proposal and release notes.
- Users may still mentally map from FlashInfer-Bench examples → Mitigation: docs should show NVBench-native examples first and mention official evaluation remains FlashInfer-Bench.
- NVBench supports broader device lists than the generated runner currently materializes → Mitigation: accept `--devices` as the NVBench-facing name, validate or constrain to a single device until multi-device materialization is supported.
- Removing `--num-trials` loses a familiar benchmarking knob → Mitigation: point users to NVBench sample controls and stopping criteria, which are the native way to control measurement effort.
