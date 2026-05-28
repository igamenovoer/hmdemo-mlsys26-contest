## 1. Variant Setup

- [x] 1.1 Create and register `moe-base` with `pixi run project-cli variant new moe-base --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- [x] 1.2 Update the live `config.toml` CUDA solution definition to `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` while preserving TVM-FFI destination-passing build metadata.
- [x] 1.3 Verify `pixi run project-cli variant list` shows `moe-base` with the exact MoE definition.

## 2. Kernel Contract

- [x] 2.1 Replace the placeholder CUDA kernel with a TVM-FFI function matching the documented MoE argument order, `int64_t local_expert_offset`, `double routed_scaling_factor`, and destination `TensorView output`.
- [x] 2.2 Add lightweight tensor validation for CUDA device, contiguity, dtype, shape, local expert offset range, and finite routing scale.
- [x] 2.3 Use the TVM-FFI caller stream for all CUDA launches and asynchronous allocations.

## 3. Routing And Workspace

- [x] 3.1 Include CUDA FP8/BF16 headers plus project-available CUTLASS/CuTe headers from `thirdparty/` without relying on ignored `extern/orphan/` paths, local install prefixes, or `CPATH`.
- [x] 3.2 Implement top-k routing that computes sigmoid scores, biased group selection, biased expert selection, and un-biased normalized routing weights.
- [x] 3.3 Allocate temporary workspace for top-k indices, top-k weights, compact local slot IDs, compact local weights, dequantized CUTLASS operands, GEMM intermediates, FP32 gated activations, and FP32 output accumulation.
- [x] 3.4 Implement compact-local-slot metadata so GEMM kernels skip selected experts outside the local 32-expert window.

## 4. MoE Compute

- [x] 4.1 Implement simple CUDA dequantization kernels that materialize compact activations and needed local expert weights into CUTLASS-friendly temporary matrices with the documented FP8 block scales.
- [x] 4.2 Implement GEMM1 over compact local slots with basic per-expert CUTLASS GEMM calls, then apply SwiGLU in an explicit CUDA kernel.
- [x] 4.3 Implement GEMM2 over compact local slots with basic per-expert CUTLASS GEMM calls, then apply routing weights and accumulate into the FP32 output buffer in explicit CUDA logic.
- [x] 4.4 Cast the FP32 output accumulation buffer to the BF16 destination tensor.
- [x] 4.5 Ensure the implementation handles `seq_len == 0` without launching invalid work.

## 5. Stock And Verification

- [x] 5.1 Stock the implemented live CUDA bundle into `variants/cuda/moe-base/` and confirm `pixi run project-cli variant status` reports `moe-base`.
- [x] 5.2 Run non-dataset checks such as `pixi run test`, `pixi run lint`, and `pixi run pack` where available.
- [x] 5.3 Run CUDA build validation with `pixi run -e cu130 nvcc --version` and a CUDA compile or pack path that exercises `solution/cuda/kernel.cu` with the `thirdparty/` CUTLASS includes.
- [x] 5.4 When CUDA and `FIB_DATASET_PATH` are available, run a small MoE correctness benchmark for `moe-base` and record whether it passes.
