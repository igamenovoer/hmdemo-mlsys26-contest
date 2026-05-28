## Why

The CUDA scaffold currently exports only a placeholder, so the repository has no minimal MoE CUDA variant that can exercise the MLSys 2026 fused MoE contract through correctness checking. A small, readable `moe-base` variant gives kernel authors a known-good baseline for the exact local MoE definition before pursuing performance-oriented optimizations.

## What Changes

- Add a registered CUDA variant named `moe-base` targeting `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- Implement a minimal TVM-FFI CUDA MoE kernel that matches the documented destination-passing signature and writes the required BF16 output.
- Keep the implementation correctness-first and easy to inspect, using straightforward routing, FP8 block-scale dequantization, SwiGLU, local-expert filtering, simple CUTLASS GEMMs, and accumulation.
- Update the live CUDA solution configuration and bundle so the `moe-base` variant can be deployed and checked with the local benchmark path.

## Capabilities

### New Capabilities

- `moe-base-cuda-variant`: Covers the repository-provided minimal CUDA TVM-FFI MoE variant and its correctness-oriented behavior for the exact fused MoE contest definition.

### Modified Capabilities

None.

## Impact

Affected areas include `config.toml`, `solution/cuda/kernel.cu`, `variants/cuda/moe-base/`, `configs/variants.toml`, and tests or validation commands around packing, variant registration, and MoE correctness checks. The change uses the project-available CUTLASS/CuTe headers under `thirdparty/` and should not rely on ignored `extern/orphan/` paths, local install prefixes, or `CPATH`.
