## Why

The current C++ profiler build flow generates a complete per-kernel NVBench runner project and recompiles slow-changing profiler/runtime code for every kernel variant. Kernel iteration should only rebuild the small kernel-dependent piece, while the NVBench runner, workload materialization, safetensors loading, and adapter host logic stay compiled once in the profiler binary.

## What Changes

- **BREAKING** Replace the current per-kernel generated runner artifact with a per-kernel shared-library plugin artifact.
- Build the static profiler/runner once as part of the `cpp/` project, including NVBench integration, workload loading, output forwarding, and timing logic.
- Change the build command to compile only a kernel plugin `.so` plus a tiny generated `tvm-ffi-moe` C ABI shim for the selected kernel and adapter.
- Change the run command to load the plugin artifact with `dlopen`, validate its ABI/version metadata, resolve the exported kernel entrypoint with `dlsym`, and time it inside the persistent NVBench runner.
- Keep artifact identity focused on kernel/plugin build inputs, not runtime workload or timing options.
- Update docs, tests, and manual smoke checks to describe the split static-runner/plugin model.

## Capabilities

### New Capabilities
- `cpp-profiler-kernel-plugin`: Builds and runs per-kernel shared-library plugins through a stable profiler-controlled C ABI while keeping the NVBench runner static.

### Modified Capabilities

## Impact

- Affected code: `cpp/src/artifact.cpp`, generated artifact CMake/source, `cpp/src/main.cpp`, runner/adapters, tests, and profiler docs.
- Affected CLI semantics: `build` still accepts kernel build inputs, but its artifact now represents a plugin `.so` instead of a complete runner binary; `run` loads that plugin artifact rather than launching an artifact-local runner executable.
- Expected benefit: repeated kernel-variant builds avoid recompiling NVBench and profiler runtime code, reducing iteration latency.
- Dependencies: no new external dependency is expected beyond platform `dlopen`/`dlsym` support on Linux.
- Existing workflows: official FlashInfer-Bench evaluation, solution packing, Modal benchmark, and project variant commands remain unchanged.
