# C++ NVBench Profiler

The C++ NVBench profiler is local development tooling for timing CUDA contest kernels without running FlashInfer-Bench reference computation or correctness checks. Official evaluation still uses `pixi run bench`, `pixi run modal-bench`, or `flashinfer-bench run`.

## Build The Tool

Install Conan dependencies and configure the C++ project from the repository root:

```bash
pixi run cpp-conan-install
pixi run cpp-configure
pixi run cpp-build
```

The default build creates the `hm-nvbench-profile` CLI and non-GPU tests. To build the reusable CUDA/NVBench runner, configure with `HM_NVPROFILE_BUILD_STATIC_RUNNER=ON` in an environment that has CUDA, TVM-FFI headers, and the local NVBench checkout:

```bash
pixi run -e cu130 cmake -S cpp -B cpp/build/cu130 \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/cpp/build/Release/build/Release/generators/conan_toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DHM_NVPROFILE_BUILD_STATIC_RUNNER=ON \
  -DHM_NVPROFILE_CUDA_ARCH=100a \
  -DHM_NVPROFILE_NVBENCH_SOURCE=extern/orphan/nvbench \
  -DHM_NVPROFILE_TVM_FFI_ROOT="$CONDA_PREFIX/lib/python3.12/site-packages/tvm_ffi" \
  -DHM_NVPROFILE_CUTLASS_INCLUDE_ROOTS="extern/orphan/cutlass/include;extern/orphan/cutlass/tools/util/include"
```

The static runner is the only target that compiles NVBench. If the current `extern/orphan/nvbench` checkout requires CMake 4.x through RAPIDS CMake, that requirement applies to the runner configure step, not to each kernel plugin artifact build.

## Build A Kernel Plugin

The profiler separates kernel compilation from runtime workload selection. Build once for a kernel, adapter, definition, compiler configuration, and include-root set:

```bash
cpp/build/Release/hm-nvbench-profile build \
  --kernel solution/cuda/kernel.cu \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --adapter tvm-ffi-moe \
  --cuda-arch 100a \
  --tvm-ffi-root "$CONDA_PREFIX/lib/python3.12/site-packages/tvm_ffi" \
  --cutlass-include-root extern/orphan/cutlass/include \
  --cutlass-include-root extern/orphan/cutlass/tools/util/include
```

The artifact is a shared library, `libhm_profile_kernel_plugin.so`, plus a manifest. It does not compile NVBench or generate a full runner project. The manifest records build inputs such as kernel content hash, adapter, definition, CUDA architecture, CUDA toolkit root, plugin ABI version, include roots, and dependency roots. Workload UUIDs, dataset paths, device IDs, timing options, and output format options are runtime inputs and do not affect artifact identity.

## Run Against Workloads

Run the existing plugin artifact through the reusable runner against workload selections without recompiling:

```bash
cpp/build/Release/hm-nvbench-profile run \
  --artifact cpp/.cache/artifacts/tvm-ffi-moe-<hash> \
  --runner cpp/build/Release/hm-nvbench-runner \
  --local extern/orphan/mlsys26-contest \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --workload b8f4f012 \
  --cold-warmup-runs 3 \
  --stopping-criterion sample-count \
  --min-samples 20 \
  --target-samples 100 \
  --timeout 300 \
  --devices 0 \
  --json tmp/nvbench-moe.json
```

You can also pass `--workload-set moe-minimal` to expand a repo-local workload set from `configs/workloads.toml`.

If `--runner` is omitted, the CLI looks for `cpp/build/Release/hm-nvbench-runner`.

## Timing Controls

The `run` command uses NVBench-native measurement option names. For fixed sample-count timing, pass `--stopping-criterion sample-count` with `--min-samples` and `--target-samples`:

```bash
cpp/build/Release/hm-nvbench-profile run \
  --artifact cpp/.cache/artifacts/tvm-ffi-moe-<hash> \
  --local extern/orphan/mlsys26-contest \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --workload b8f4f012 \
  --stopping-criterion sample-count \
  --min-samples 20 \
  --target-samples 100
```

For variance-converged timing, use NVBench's `stdrel` criterion and set the relative noise threshold with `--max-noise`. NVBench interprets `--max-noise` as a percentage, so `0.5` means 0.5% relative standard deviation. `--min-time` sets the minimum accumulated measurement time before convergence can stop:

```bash
cpp/build/Release/hm-nvbench-profile run \
  --artifact cpp/.cache/artifacts/tvm-ffi-moe-<hash> \
  --local extern/orphan/mlsys26-contest \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --workload b8f4f012 \
  --stopping-criterion stdrel \
  --min-samples 10 \
  --max-noise 0.5 \
  --min-time 0.2 \
  --devices 0
```

Passing `--max-noise` or `--min-time` without `--stopping-criterion` implies `stdrel`. Passing those options with `sample-count` or `entropy` is rejected because NVBench only applies them to the `stdrel` stopping criterion. `--target-samples` is accepted only with `sample-count`; use `--min-samples` for criterion-independent minimum samples.

FlashInfer-Bench-style aliases are intentionally not part of the C++ profiler CLI. Use `--cold-warmup-runs` instead of `--warmup-runs`, `--devices` instead of `--device`, and `--min-samples`/`--target-samples` instead of `--iterations`. Correctness options such as `--rtol`, `--atol`, and `--required-matched-ratio` belong to official FlashInfer-Bench evaluation, not this timing-only profiler.

## Plugin ABI

The generated kernel shim exports a small C ABI: `hm_profile_plugin_abi_version`, `hm_profile_plugin_adapter`, `hm_profile_plugin_last_error`, and `hm_profile_moe_kernel_v1`. The first supported adapter is `tvm-ffi-moe`; the entrypoint receives DLPack `DLTensor*` arguments plus the scalar MoE arguments, invokes `moe_tvm_ffi::Kernel`, returns `0` on success, and reports failures through `hm_profile_plugin_last_error`.

Old artifacts that contain an artifact-local `hm-nvbench-runner` are not compatible with this layout. Rebuild the artifact with the current `build` command to produce a plugin manifest and shared library.

## Scope

The first adapter is `tvm-ffi-moe`, which targets the MoE TVM-FFI destination-passing signature. The static runner materializes inputs and outputs outside the measured region, sets the TVM-FFI stream to NVBench's launch stream, and times only the plugin kernel call. Official correctness checks and speedup comparisons remain in FlashInfer-Bench.
