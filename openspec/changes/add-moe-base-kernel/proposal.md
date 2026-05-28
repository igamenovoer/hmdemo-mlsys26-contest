## Why

The project has the contest MoE callable contract documented, but it does not yet provide a runnable CUDA baseline for that exact contract. Adding `moe-base` gives us a concrete starting point for correctness, benchmarking, and later optimization of the fused MoE workload.

## What Changes

- Add a `moe-base` CUDA variant targeting `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- Implement the contest TVM-FFI destination-passing signature for the MoE contract in `solution/cuda/kernel.cu` or an equivalent variant bundle.
- Use CUTLASS headers for the GEMM portions of the MoE pipeline while keeping routing, token bucketing, activation, and final scatter/accumulation in CUDA kernels.
- Keep the implementation development-oriented for the first baseline: allow the local pack/build path to pull header-only CUTLASS files from `extern/orphan/cutlass`, while keeping non-header-only CUDA libraries out of scope.
- Add validation guidance for building, packing, and running correctness-gated timing through the existing contest tools.

## Capabilities

### New Capabilities

- `moe-base-kernel`: Defines the `moe-base` CUDA solution variant for the contest MoE contract, including interface, dependency, correctness, and validation expectations.

### Modified Capabilities

- None.

## Impact

- Affects the CUDA solution source under `solution/cuda/` or the variant material used to deploy `moe-base`.
- Affects variant registration and configuration so `moe-base` points at the exact MoE definition ID.
- May add development packer support for recursively including header-only CUTLASS files from `extern/orphan/cutlass/include`.
- Uses CUDA Toolkit-provided headers such as CCCL/CUB/Thrust when helpful, without adding external link-time dependencies.
