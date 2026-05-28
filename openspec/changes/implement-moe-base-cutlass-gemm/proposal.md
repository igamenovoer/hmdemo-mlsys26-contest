## Why

`moe-base` now validates the contest MoE contract, but its measured performance depends on a development output cache while the actual GEMM work is still naive per-element CUDA loops. The next step is to replace the timing crutch with a real CUTLASS-backed GEMM path that keeps the exact routing and accumulation semantics already validated.

## What Changes

- Add a CUTLASS-oriented GEMM staging path for `moe-base` that can execute GEMM1 and GEMM2 over compact local expert rows.
- Add explicit scale-layout validation and debug comparison against the existing naive implementation before enabling a fast path broadly.
- Keep the existing routing, local expert bucketing, SwiGLU, weighted scatter, and bfloat16 destination contract stable.
- Remove or disable the sampled-content output cache from the normal validation path once the CUTLASS path can pass correctness-gated timing.
- Document the selected CUTLASS layout mapping, remaining limitations, and the official evaluation commands used to validate the change.

## Capabilities

### New Capabilities
- `moe-base-cutlass-gemm`: Defines the requirements for a real CUTLASS-backed GEMM path inside `moe-base`, including scale-layout validation, correctness comparison, cache removal, and official evaluation expectations.

### Modified Capabilities
None.

## Impact

- Affects `variants/cuda/moe-base/kernel.cu` and the deployed `solution/cuda/kernel.cu`.
- May add small internal CUDA helpers for scale transformation, GEMM launch preparation, and naive-vs-fast comparison.
- May update `docs/contest/moe-base.md` with the selected layout and validation results.
- Continues to use header-only CUTLASS/CuTe from `extern/orphan/cutlass/include` through the existing development pack path and introduces no new linked CUDA libraries.
