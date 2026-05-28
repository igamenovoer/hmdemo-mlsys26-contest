## 1. CLI Surface Cleanup

- [x] 1.1 Replace `--warmup-runs` with `--cold-warmup-runs` in the C++ profiler `run` command.
- [x] 1.2 Replace `--device` with `--devices` in the C++ profiler `run` command and validate or constrain the supported device selection.
- [x] 1.3 Remove `--iterations` and rely on `--min-samples` and `--target-samples` for sample-count timing.
- [x] 1.4 Remove `--num-trials` and the runtime workload duplication it triggers.
- [x] 1.5 Remove `--rtol`, `--atol`, and `--required-matched-ratio` from the C++ profiler `run` command.
- [x] 1.6 Remove `--random-seed` from the C++ profiler `run` command unless implementation also adds real seeded random tensor materialization.

## 2. NVBench Forwarding Semantics

- [x] 2.1 Forward `--cold-warmup-runs` directly to the artifact runner.
- [x] 2.2 Forward `--devices` to NVBench and keep the generated runner's private device selection consistent with the supported device value.
- [x] 2.3 Keep forwarding `--stopping-criterion`, `--min-samples`, `--target-samples`, `--max-noise`, `--min-time`, and `--timeout`.
- [x] 2.4 Preserve validation that `--target-samples` is only used with `sample-count`.
- [x] 2.5 Preserve validation that `--max-noise` and `--min-time` are only used with `stdrel`, including implicit `stdrel` when no criterion is provided.
- [x] 2.6 Ensure timing, output, and device options remain runtime-only and do not affect artifact build identity.

## 3. Tests

- [x] 3.1 Update non-GPU tests to assert `run --help` source coverage for `--cold-warmup-runs`, `--devices`, `--min-samples`, and `--target-samples`.
- [x] 3.2 Update non-GPU tests to assert removed options are no longer listed or parsed by the C++ profiler source.
- [x] 3.3 Add or update tests for NVBench-native forwarding and validation behavior.
- [x] 3.4 Run `pixi run cpp-build`, `pixi run cpp-test`, and targeted unit tests.

## 4. Documentation And OpenSpec

- [x] 4.1 Update C++ profiler docs and examples to use NVBench-native `run` options.
- [x] 4.2 Document replacement guidance for removed FlashInfer-Bench-style aliases.
- [x] 4.3 Run `openspec validate make-cpp-profiler-nvbench-native-cli`.
