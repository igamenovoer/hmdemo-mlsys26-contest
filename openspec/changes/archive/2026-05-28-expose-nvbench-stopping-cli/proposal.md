## Why

The C++ NVBench profiler currently exposes fixed sample-count timing through `--iterations`, but NVBench also supports convergence-based timing using stopping criteria and runtime variance thresholds. Exposing those controls makes the profiler useful for both fast deterministic sweeps and more statistically stable measurements without requiring users to pass raw NVBench arguments outside the repo's CLI.

## What Changes

- Add profiler `run` CLI options for NVBench stopping criterion selection and criterion parameters.
- Preserve the existing `--iterations` compatibility behavior as a convenient fixed sample-count alias.
- Add explicit variance/convergence controls such as maximum relative noise and minimum sample/time settings for NVBench's `stdrel` stopping criterion.
- Document the mapping between profiler options and NVBench runner arguments.
- Add non-GPU tests that verify CLI option mapping and artifact reuse remains independent of timing controls.

## Capabilities

### New Capabilities
- `nvbench-stopping-cli`: Exposes NVBench stopping criteria and convergence parameters through the C++ profiler CLI.

### Modified Capabilities

## Impact

- Affected code: `cpp/src/main.cpp`, generated runner command construction tests, and profiler documentation.
- Affected CLI: `hm-nvbench-profile run`.
- Dependencies: no new C++ or Python dependencies expected.
- Existing workflows: `pixi run bench`, `pixi run pack`, Modal benchmark, and project variant commands remain unchanged.
