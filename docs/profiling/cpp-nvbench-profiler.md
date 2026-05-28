# C++ NVBench Profiler

The C++ NVBench profiler is local development tooling for timing CUDA contest kernels without running FlashInfer-Bench reference computation or correctness checks. Official evaluation still uses `pixi run bench`, `pixi run modal-bench`, or `flashinfer-bench run`.

## Build The Tool

Install Conan dependencies and configure the C++ project from the repository root:

```bash
pixi run cpp-conan-install
pixi run cpp-configure
pixi run cpp-build
```

In the CUDA 13 environment, pass the CUDA-specific roots to CMake when needed:

```bash
pixi run -e cu130 cmake -S cpp -B cpp/build/cu130 \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/cpp/build/Release/build/Release/generators/conan_toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DHM_NVPROFILE_CUDA_ARCH=100a \
  -DHM_NVPROFILE_NVBENCH_SOURCE=extern/orphan/nvbench \
  -DHM_NVPROFILE_TVM_FFI_ROOT="$CONDA_PREFIX/lib/python3.12/site-packages/tvm_ffi" \
  -DHM_NVPROFILE_CUTLASS_INCLUDE_ROOTS="extern/orphan/cutlass/include;extern/orphan/cutlass/tools/util/include"
```

## Build A Reusable Artifact

The profiler separates compilation from runtime workload selection. Build once for a kernel, adapter, definition, compiler configuration, and include-root set:

```bash
cpp/build/Release/hm-nvbench-profile build \
  --kernel solution/cuda/kernel.cu \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --adapter tvm-ffi-moe \
  --cuda-arch 100a \
  --nvbench-source extern/orphan/nvbench \
  --tvm-ffi-root "$CONDA_PREFIX/lib/python3.12/site-packages/tvm_ffi" \
  --cutlass-include-root extern/orphan/cutlass/include \
  --cutlass-include-root extern/orphan/cutlass/tools/util/include
```

The artifact manifest records build inputs such as kernel content hash, adapter, definition, CUDA architecture, include roots, and dependency roots. Workload UUIDs, dataset paths, device IDs, timing options, and output format options are runtime inputs and do not affect artifact identity.

When using the current `extern/orphan/nvbench` `main` checkout, artifact compilation may require CMake 4.0 or newer because NVBench fetches RAPIDS CMake 25.12 during configure. The profiler passes the Pixi/PyPI CUDA 13 root and `libcudart` path into the generated artifact CMake configure step, but the CMake version still comes from the active environment. Use a CMake 4.x environment or pin NVBench to a revision compatible with the repo's CMake 3.31 environment before running the non-`--skip-compile` artifact build.

## Run Against Workloads

Run the existing artifact against workload selections without recompiling:

```bash
cpp/build/Release/hm-nvbench-profile run \
  --artifact cpp/.cache/artifacts/tvm-ffi-moe-<hash> \
  --local extern/orphan/mlsys26-contest \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --workload b8f4f012 \
  --warmup-runs 3 \
  --iterations 100 \
  --timeout 300 \
  --device 0 \
  --json tmp/nvbench-moe.json
```

You can also pass `--workload-set moe-minimal` to expand a repo-local workload set from `configs/workloads.toml`.

## Timing Controls

By default, the profiler uses NVBench's fixed sample-count stopping criterion. `--iterations N` is a compatibility alias for fixed timing and forwards `--stopping-criterion sample-count --min-samples N --target-samples N` to the artifact runner:

```bash
cpp/build/Release/hm-nvbench-profile run \
  --artifact cpp/.cache/artifacts/tvm-ffi-moe-<hash> \
  --local extern/orphan/mlsys26-contest \
  --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 \
  --workload b8f4f012 \
  --iterations 100
```

For more explicit fixed sample-count control, pass `--min-samples` and `--target-samples`:

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
  --min-time 0.2
```

Passing `--max-noise` or `--min-time` without `--stopping-criterion` implies `stdrel`. Passing those options with `sample-count` or `entropy` is rejected because NVBench only applies them to the `stdrel` stopping criterion. `--target-samples` is accepted only with `sample-count`; use `--min-samples` for criterion-independent minimum samples.

## Scope

The first adapter is `tvm-ffi-moe`, which targets the MoE TVM-FFI destination-passing signature. The generated runner materializes inputs and outputs outside the measured region, sets the TVM-FFI stream to NVBench's launch stream, and times only the solution kernel call. Correctness-only options such as `--rtol`, `--atol`, and `--required-matched-ratio` are intentionally rejected.
