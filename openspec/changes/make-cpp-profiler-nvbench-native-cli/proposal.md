## Why

The C++ profiler is intended for independent kernel timing with NVBench, but its `run` CLI still includes FlashInfer-Bench compatibility names and rejected correctness options. Aligning overlapping measurement controls with NVBench semantics makes the tool clearer, reduces surprising aliases, and keeps the profiler independent from FlashInfer-Bench evaluation workflows.

## What Changes

- **BREAKING** Remove FlashInfer-Bench compatibility timing aliases from the C++ profiler `run` CLI where NVBench-native equivalents exist.
- **BREAKING** Remove correctness-only compatibility options from the C++ profiler `run` CLI instead of accepting and rejecting them.
- Rename or replace overlapping measurement options with NVBench-native names and semantics, such as `--cold-warmup-runs` and `--devices`.
- Keep profiler-specific selection options for artifacts, datasets, definitions, workloads, and workload sets.
- Keep NVBench-native output and stopping controls such as `--stopping-criterion`, `--min-samples`, `--target-samples`, `--max-noise`, `--min-time`, `--timeout`, `--json`, `--csv`, and `--markdown`.
- Document the resulting CLI as NVBench-native local profiling rather than FlashInfer-Bench-compatible benchmarking.

## Capabilities

### New Capabilities
- `cpp-profiler-nvbench-native-cli`: Defines the C++ profiler `run` CLI policy and supported options when NVBench and FlashInfer-Bench semantics overlap.

### Modified Capabilities

## Impact

- Affected code: `cpp/src/main.cpp`, CLI tests, docs, and manual profiler examples.
- Affected users: existing local invocations using `--iterations`, `--warmup-runs`, `--num-trials`, `--device`, `--rtol`, `--atol`, or `--required-matched-ratio` will need to switch to NVBench-native options or remove correctness-only flags.
- Dependencies: no new C++ or Python dependencies expected.
- Existing workflows: `pixi run bench`, `pixi run modal-bench`, solution packing, and project variant commands remain unchanged.
