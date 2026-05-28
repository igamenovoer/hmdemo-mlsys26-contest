## Why

The current `moe-base` direction drifted toward a generic CUTLASS GEMM bridge, but the contest baseline for this definition is FlashInfer's `trtllm_fp8_block_scale_moe` path. We need a corrected baseline plan that follows that core MoE dataflow and adapts it to the contest TVM-FFI destination-passing CUDA contract.

## What Changes

- Reframe `moe-base` as a FlashInfer-baseline-compatible CUDA implementation for `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- Adapt the baseline Python wrapper behavior to the CUDA TVM-FFI destination-passing interface: fixed MoE constants, input layout assumptions, DeepSeekV3 routing mode, MajorK expert weights, Swiglu activation, and bfloat16 output.
- Use source-packable CUDA/CUTLASS/CuTe implementation pieces for the MoE stages instead of relying on installed FlashInfer Python, FlashInfer cubin packages, local `extern/orphan/` paths, CMake installs, or runtime `CPATH`.
- Prefer FlashInfer source as reference for DeepSeekV3 routing, activation, finalize, and TensorRT-LLM runner semantics, while using CUTLASS/CuTe Blackwell references for the FP8 block-scale GEMM stages.
- Supersede the generic `implement-moe-base-cutlass-gemm` framing for this kernel path; CUTLASS remains a tool for the GEMM stages, not the top-level design.
- Define validation expectations for pack/build, correctness-gated official evaluation, and idle-GPU-only benchmark execution.

## Capabilities

### New Capabilities
- `moe-base-flashinfer-baseline`: Defines requirements for a `moe-base` CUDA variant that follows the FlashInfer contest baseline semantics while conforming to the TVM-FFI destination-passing MoE contract.

### Modified Capabilities
- None.

## Impact

- Affects `variants/cuda/moe-base/kernel.cu` and the deployed `solution/cuda/kernel.cu`.
- May add tracked solution-local CUDA headers or helper translation units for routing, scale layout adapters, workspace management, CUTLASS GEMM launch wrappers, activation, and finalize.
- May update packer/config behavior so any required source-packable headers are bundled intentionally with the solution rather than referenced from ignored external checkouts at runtime.
- Uses `extern/orphan/mlsys26-contest`, `extern/orphan/flashinfer`, `extern/orphan/flashinfer-bench`, and `extern/orphan/cutlass` as reference material; final packed sources must not depend on those paths being present.
- Updates `docs/contest/moe-base.md` or nearby documentation to record the FlashInfer baseline mapping, selected source references, and official evaluation results.
