#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found; CUDA smoke check requires a CUDA-capable host" >&2
  exit 2
fi

dataset_root="${FIB_DATASET_PATH:-extern/orphan/mlsys26-contest}"
definition="moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048"
tool="cpp/build/Release/hm-nvbench-profile"

if [[ ! -x "$tool" ]]; then
  echo "$tool is missing; run pixi run cpp-conan-install && pixi run cpp-configure && pixi run cpp-build first" >&2
  exit 2
fi

artifact="$($tool build \
  --kernel solution/cuda/kernel.cu \
  --definition "$definition" \
  --adapter tvm-ffi-moe \
  --cuda-arch 100a \
  --nvbench-source extern/orphan/nvbench \
  --tvm-ffi-root "${CONDA_PREFIX}/lib/python3.12/site-packages/tvm_ffi" \
  --cutlass-include-root extern/orphan/cutlass/include \
  --cutlass-include-root extern/orphan/cutlass/tools/util/include)"

"$tool" run \
  --artifact "$artifact" \
  --local "$dataset_root" \
  --definition "$definition" \
  --workload b8f4f012 \
  --warmup-runs 1 \
  --iterations 1 \
  --timeout 300 \
  --device 0 \
  --json tmp/cpp-nvbench-smoke.json
