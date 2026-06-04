## 1. Plugin ABI And Shared Types

- [x] 1.1 Define a small versioned C ABI header for profiler plugins, including ABI version, adapter identity, status/error behavior, and the `tvm-ffi-moe` function pointer signature.
- [x] 1.2 Add a loader abstraction that owns `dlopen`/`dlclose`, resolves required plugin symbols, validates ABI version and adapter identity, and exposes a typed MoE entrypoint.
- [x] 1.3 Add unit-testable error paths for missing plugin library, missing symbols, unsupported ABI version, and adapter mismatch.

## 2. Static Runner Refactor

- [x] 2.1 Move generated runner-only code into tracked C++/CUDA sources built by the main `cpp/` project instead of rendering it per artifact.
- [x] 2.2 Build a reusable NVBench runner target or integrate runner execution into `hm-nvbench-profile` so NVBench and workload materialization compile once.
- [x] 2.3 Keep workload context loading, safetensors reading, CUDA tensor allocation, workload axis injection, and workload UUID output metadata in the static runner.
- [x] 2.4 Replace direct `moe_tvm_ffi::Kernel` calls with invocation through the loaded plugin entrypoint.
- [x] 2.5 Preserve TVM-FFI stream setup and restoration around the timed plugin call.

## 3. Kernel Plugin Artifact Build

- [x] 3.1 Change artifact generation to create a tiny plugin source or shim for the selected kernel and adapter rather than a complete runner source.
- [x] 3.2 Generate a plugin build configuration that compiles a shared library without adding or compiling NVBench.
- [x] 3.3 Export plugin ABI metadata symbols and the `tvm-ffi-moe` C ABI entrypoint from the generated shim.
- [x] 3.4 Catch plugin-side C++ exceptions in the shim and expose a status/error mechanism usable by the static runner.
- [x] 3.5 Update artifact manifest fields to record `plugin_library`, plugin ABI version, adapter, kernel/build identity, and dependency roots instead of an artifact-local runner binary.
- [x] 3.6 Preserve build-input hashing for kernel source, adapter, definition, CUDA architecture, include roots, compiler flags, TVM-FFI/CUDA roots, and plugin ABI version.

## 4. Run Command Integration

- [x] 4.1 Update `run` validation to require a plugin artifact manifest and existing plugin shared library.
- [x] 4.2 Pass plugin path and runtime context to the static runner without invoking the build step.
- [x] 4.3 Preserve NVBench-native timing, device, and output option forwarding from the current CLI.
- [x] 4.4 Verify workload selection, workload sets, timing options, output options, and device options do not affect plugin artifact identity.

## 5. Tests And Manual Checks

- [x] 5.1 Add non-GPU tests for manifest JSON shape, plugin artifact identity, and absence of NVBench in generated plugin build files.
- [x] 5.2 Add non-GPU tests for plugin loader validation failures using missing or intentionally incomplete plugin paths.
- [x] 5.3 Update existing source-level CLI tests to expect plugin artifacts instead of runner binary artifacts.
- [x] 5.4 Update the CUDA-capable manual smoke script to build a plugin artifact and run it through the static runner against at least one MoE workload.
- [x] 5.5 Run `pixi run cpp-build`, `pixi run cpp-test`, targeted unit tests, and default `pixi run test`.

## 6. Documentation And OpenSpec

- [x] 6.1 Update profiler documentation to explain the static-runner plus per-kernel plugin architecture.
- [x] 6.2 Document the plugin ABI symbols and the `tvm-ffi-moe` shim contract at a high level.
- [x] 6.3 Document migration from old runner artifacts to plugin artifacts.
- [x] 6.4 Run `openspec validate split-profiler-runner-kernel-plugin`.
