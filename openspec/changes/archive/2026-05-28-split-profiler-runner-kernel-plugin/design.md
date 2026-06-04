## Context

The current C++ profiler artifact model copies the selected kernel source, renders a complete NVBench runner source file, writes a standalone CMake project, and builds an artifact-local executable. That makes every kernel variant rebuild NVBench integration, workload loading, safetensors reading, DLTensor/TensorView construction, adapter host code, and generated runner code, even though only `kernel.cu` changes during most tuning loops. The solution kernel already exports a TVM-FFI function, but for profiler speed and simplicity this change chooses Option B: generate a tiny profiler-controlled C ABI shim in a per-kernel shared library and keep the runner static.

## Goals / Non-Goals

**Goals:**
- Build the NVBench runner and profiler runtime once as part of the normal `cpp/` project.
- Make `hm-nvbench-profile build` compile only a per-kernel plugin `.so` and manifest.
- Use a stable C ABI exported by the plugin, starting with `tvm-ffi-moe`, so the static runner can call kernels through `dlopen`/`dlsym`.
- Preserve runtime workload selection, NVBench-native timing controls, output forwarding, and artifact reuse semantics.
- Keep plugin rebuild identity limited to kernel source and plugin build inputs, not workload or timing inputs.

**Non-Goals:**
- Do not change official FlashInfer-Bench evaluation, solution packing, Modal benchmark, or project variant workflows.
- Do not require arbitrary TVM-FFI packed-call loading in the first implementation.
- Do not support multi-adapter plugin ABIs beyond `tvm-ffi-moe` unless the surrounding structure makes that trivial.
- Do not eliminate the cost of compiling the kernel implementation itself; the goal is to avoid recompiling the profiler runner and NVBench stack per variant.

## Decisions

1. Use a generated C ABI shim rather than calling `__tvm_ffi_kernel` directly. The shim includes or references the selected kernel source, constructs `tvm::ffi::TensorView` objects from `DLTensor*` arguments, calls `moe_tvm_ffi::Kernel`, catches C++ exceptions, and returns a profiler-defined status code. This keeps the static runner's dynamic-call path simple and avoids teaching it the TVM-FFI packed-call ABI in this change.

2. Define a versioned plugin ABI. The first ABI should export names such as `hm_profile_plugin_abi_version`, `hm_profile_plugin_adapter`, and `hm_profile_moe_kernel_v1`. The runner validates the ABI version and adapter string before benchmarking. A minimal function pointer type can use `DLTensor*` arguments, `int64_t local_expert_offset`, and `double routed_scaling_factor`, matching the current MoE destination-passing call.

3. Move the NVBench runner into the static C++ project. Instead of rendering `runner.cu` into every artifact, the `cpp/` build should produce a persistent runner executable or link runner logic into `hm-nvbench-profile`. The runner owns NVBench registration, `workload_index` axis injection, workload materialization, stream setup, and result metadata. The `run` command should execute or dispatch this static runner with plugin path and context path.

4. Change artifact contents from executable runner to plugin package. A plugin artifact should contain `manifest.json`, generated shim source, copied or referenced kernel source, optional generated CMake/Ninja build files, and the compiled shared library path, for example `libhm-profile-kernel.so`. The manifest should record `plugin_library` instead of `runner_binary`.

5. Keep plugin artifacts content-addressed by build inputs. The build hash includes kernel source content, adapter, definition identity, CUDA architecture, include roots, compiler flags, TVM-FFI/CUDA dependency roots, shim ABI version, and profiler plugin ABI version. Runtime inputs such as dataset root, workload selection, device, timing controls, and output paths remain excluded.

6. Prefer a small generated plugin build over a generated full project. The first implementation may still generate a tiny CMake project or direct compile command for the plugin, but it must not `add_subdirectory` NVBench or compile runner code per kernel artifact.

## Risks / Trade-offs

- C ABI design can ossify too early → Mitigation: version the ABI and validate version/adapter at load time.
- Kernel exceptions crossing plugin boundaries can be messy → Mitigation: catch exceptions in the generated shim and expose an error string accessor or status code before returning to the runner.
- Symbol visibility and CUDA runtime linking can be finicky → Mitigation: generate explicit `extern "C"` exported symbols and keep CUDA/CUDART discovery logic in the plugin build path.
- Static runner still needs CUDA compilation because it uses NVBench CUDA launch types and DLTensor allocation → Mitigation: build it once in `cpp/`, not per kernel.
- Plugin build may still be expensive for CUTLASS-heavy kernels → Mitigation: this change removes repeated runner/NVBench compilation but does not claim to make kernel template compilation cheap.
