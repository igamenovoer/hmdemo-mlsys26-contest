## 1. CLI Option Model

- [x] 1.1 Add `run` options for `--stopping-criterion`, `--min-samples`, `--target-samples`, `--max-noise`, and `--min-time` in `cpp/src/main.cpp`.
- [x] 1.2 Restrict `--stopping-criterion` to supported NVBench criteria: `sample-count`, `stdrel`, and `entropy`.
- [x] 1.3 Define precedence between `--iterations`, `--min-samples`, and `--target-samples`, and implement validation or override behavior consistently.
- [x] 1.4 Preserve existing default behavior where omitted stopping controls run fixed sample-count timing.

## 2. NVBench Argument Mapping

- [x] 2.1 Forward selected stopping criterion to the artifact runner as `--stopping-criterion`.
- [x] 2.2 Forward explicit sample controls to the artifact runner as `--min-samples` and `--target-samples`.
- [x] 2.3 Keep `--iterations N` mapped to `--min-samples N --target-samples N` when explicit sample controls are absent.
- [x] 2.4 Forward `--max-noise` and `--min-time` to the artifact runner for `stdrel` runs.
- [x] 2.5 Make `--max-noise` or `--min-time` imply `stdrel` when no stopping criterion is provided.
- [x] 2.6 Reject `--max-noise` or `--min-time` when the selected stopping criterion is not `stdrel`.

## 3. Artifact Reuse And Runtime Scope

- [x] 3.1 Verify stopping and sample controls are not included in artifact manifest build identity.
- [x] 3.2 Verify changing stopping and sample controls does not invoke the build command or require artifact recompilation.
- [x] 3.3 Keep correctness-only options rejected and separate from timing-only NVBench controls.

## 4. Tests And Documentation

- [x] 4.1 Add non-GPU tests for default sample-count mapping.
- [x] 4.2 Add non-GPU tests for explicit `stdrel` mapping with `--max-noise` and `--min-time`.
- [x] 4.3 Add non-GPU tests for invalid criterion and incompatible variance-control combinations.
- [x] 4.4 Update profiler documentation with the timing option mapping and examples for fixed sample-count and variance-converged runs.
- [x] 4.5 Run `pixi run cpp-build`, `pixi run cpp-test`, targeted unit tests, and `openspec validate expose-nvbench-stopping-cli`.
