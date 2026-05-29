# NVBench Timing

Time a CUDA variant directly with the repo C++ NVBench profiler. This path is independent of FlashInfer-Bench: it does not compute correctness, reference latency, or speedup. Use `official-timing` when correctness or contest scoring matters.

## Scope

| Kernel Type | Definition | Status |
|---|---|---|
| MoE | `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` | Supported through adapter `tvm-ffi-moe`. |
| DSA/GDN | any | Not covered yet; stop and say this subskill currently covers MoE only. |

## Inputs

- `variant`: Registered variant id from `configs/variants.toml` or a variant directory path.
- `definition`: Exact workload definition. Infer from variant metadata when possible.
- `dataset_root`: Local trace dataset root, usually `extern/orphan/mlsys26-contest` or the `contest-local` source.
- `workloads`: UUIDs, prefixes, or workload set. Use a small representative workload first.
- `result_dir`: Directory for artifacts, runner logs, and NVBench JSON/CSV/Markdown.

## Resolve MoE Variant

- Registered id: Read `configs/variants.toml`; resolve `path` under `variants/`; use its `definition`.
- Directory path: Read `<variant-dir>/variant.toml` if present; otherwise require `definition`.
- Kernel source: Use `<variant-dir>/kernel.cu`; do not deploy into `solution/cuda/` just to time.

Reject non-MoE definitions for now. For MoE, use:

```bash
definition=moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048
adapter=tvm-ffi-moe
```

## Probes

```bash
pixi run project-cli workload source list
pixi run project-cli workload list --source contest-local --definition <definition> --limit 5
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits
pixi run -e cu130 bash -lc 'echo CUDA_HOME=$CUDA_HOME; command -v nvcc; cmake --version | head -1; test -d "$CONDA_PREFIX/lib/python3.12/site-packages/tvm_ffi" && echo tvm_ffi_ok'
```

Use an idle GPU. Prefer `thirdparty/cutlass/include` for project variants such as `moe-base`; do not depend on ignored `extern/orphan/cutlass` headers for submitted/project kernels.

## Build CLI And Static Runner

Build the default CLI if missing or stale:

```bash
pixi run cpp-conan-install
pixi run cpp-configure
pixi run cpp-build
```

Build the reusable runner once. If the local NVBench checkout requires CMake 4.x and Pixi only has CMake 3.x, install/use a temporary CMake wheel under `tmp/` and record that choice.

```bash
python -m venv tmp/cmake4-venv
tmp/cmake4-venv/bin/pip install 'cmake>=4.0,<5'

pixi run -e cu130 tmp/cmake4-venv/bin/cmake -S cpp -B cpp/build/cu130-static-cmake4 \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/cpp/build/Release/build/Release/generators/conan_toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DHM_NVPROFILE_BUILD_STATIC_RUNNER=ON \
  -DHM_NVPROFILE_CUDA_ARCH=100a \
  -DHM_NVPROFILE_NVBENCH_SOURCE="$PWD/extern/orphan/nvbench" \
  -DHM_NVPROFILE_TVM_FFI_ROOT="$PWD/.pixi/envs/cu130/lib/python3.12/site-packages/tvm_ffi" \
  -DHM_NVPROFILE_CUTLASS_INCLUDE_ROOTS="$PWD/thirdparty/cutlass/include" \
  -DCUDAToolkit_ROOT=/usr/local/cuda-13.0 \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.0/bin/nvcc

pixi run -e cu130 tmp/cmake4-venv/bin/cmake --build cpp/build/cu130-static-cmake4 --target hm-nvbench-runner -j 8
```

If `cpp/build/Release/hm-nvbench-runner` already exists and matches the current profiler sources, it may be used instead. When using a non-default build directory, pass `--runner <path>`.

## Build Kernel Plugin

Build a per-kernel plugin artifact. The plugin build compiles only the kernel shim and shared library; it should not compile NVBench.

```bash
artifact="$(pixi run -e cu130 cpp/build/Release/hm-nvbench-profile build \
  --kernel <variant-dir>/kernel.cu \
  --definition <definition> \
  --adapter tvm-ffi-moe \
  --cuda-arch 100a \
  --artifact-root <result-dir>/nvbench/artifacts \
  --tvm-ffi-root "$PWD/.pixi/envs/cu130/lib/python3.12/site-packages/tvm_ffi" \
  --cutlass-include-root "$PWD/thirdparty/cutlass/include")"
```

Use `--force` after changing the profiler-generated shim or when refreshing an existing artifact. Runtime workload choices, device id, and timing options should not change artifact identity.

## Run Timing

Prefer a quick sample-count run first:

```bash
CUDA_VISIBLE_DEVICES=<gpu> \
pixi run -e cu130 cpp/build/Release/hm-nvbench-profile run \
  --artifact "$artifact" \
  --runner cpp/build/cu130-static-cmake4/hm-nvbench-runner \
  --local <dataset_root> \
  --definition <definition> \
  --workload <uuid-or-prefix> \
  --cold-warmup-runs 1 \
  --stopping-criterion sample-count \
  --min-samples 10 \
  --target-samples 20 \
  --timeout 300 \
  --devices 0 \
  --json <result-dir>/nvbench/<variant-label>-<workload-label>.json
```

For convergence-style timing, use NVBench semantics:

```bash
--stopping-criterion stdrel --min-samples 10 --max-noise 0.5 --min-time 0.2
```

Do not use FlashInfer-Bench aliases such as `--iterations`, `--warmup-runs`, `--device`, `--rtol`, or `--atol` with the C++ profiler.

## Parse Latency

Extract mean GPU time, sample count, and noise from NVBench JSON:

```bash
python - <<'PY'
import json
from pathlib import Path

path = Path("<result-dir>/nvbench/<file>.json")
data = json.loads(path.read_text())
for bench in data["benchmarks"]:
    for state in bench["states"]:
        values = {}
        for summary in state["summaries"]:
            tag = summary.get("tag")
            items = summary.get("data") or []
            if items:
                values[tag] = items[0]["value"]
        gpu_s = float(values["nv/cold/time/gpu/mean"])
        noise = float(values["nv/cold/time/gpu/stdev/relative"]) * 100.0
        samples = int(values["nv/cold/sample_size"])
        uuid = values.get("workload_uuid", "")
        print(f"{uuid} gpu_ms={gpu_s * 1000:.6f} samples={samples} gpu_noise_pct={noise:.3f}")
PY
```

Report the displayed table value too when present. Always include GPU model/id, definition, workload UUID/prefix and axes, sample count, stopping criterion, runner path, artifact path, and JSON path.

## Failure Handling

- Static runner missing: Build `hm-nvbench-runner` with `HM_NVPROFILE_BUILD_STATIC_RUNNER=ON` or pass `--runner`.
- CMake asks for 4.x while configuring NVBench: Use a temporary CMake 4 wheel under `tmp/` or another discovered CMake 4 binary; keep the command in the report.
- Plugin configure cannot find `CUDA::cudart`: Use the current profiler CMake fallback or pass a CUDA toolkit root from `pixi run -e cu130 env`; do not hand-edit generated artifacts unless diagnosing.
- Plugin fails with missing kernel symbol: Confirm the shim calls the contest CUDA function exposed by the variant, currently `hmdemo_mlsys26_contest::kernel` for MoE.
- NVBench deadlock/no data: The runner must use NVBench `sync | timer` for kernels that synchronize internally. Treat no-data output as invalid and rebuild the runner after fixing.
- Output exists but correctness is unknown: Expected; NVBench timing is timing-only. Run `official-timing` for correctness.

## Report

Use this shape:

```text
Variant: <id-or-path>
Definition: <definition>
Workload: <uuid> (<axes>)
GPU: <id> <name>
NVBench: <stopping criterion>, <samples>x, cold warmup <n>
Latency: <gpu_ms> ms mean GPU time (<noise>% noise)
Artifacts: plugin=<artifact>, runner=<runner>, json=<json>
Notes: correctness not checked by NVBench; use official-timing for contest-valid result.
```
