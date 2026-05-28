## Context

The repository is configured for CUDA TVM-FFI submissions, but the live CUDA kernel and default CUDA template are placeholders. The contest MoE contract is documented in `docs/contest/kernel-contracts.md` and points to a single exact definition, `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`, where only `seq_len` varies. Local workloads include very small sequences and large sequences up to 14107 tokens, so a base kernel must prioritize correctness without accidentally doing unnecessary work for non-local experts.

The Python reference in the local MoE definition establishes the required semantics: DeepSeek no-aux routing uses sigmoid scores plus BF16 routing bias for selection, un-biased sigmoid scores for normalized weights, top-4 expert groups, top-8 experts, FP8 block-scale dequantization for activations and weights, SwiGLU between GEMM1 and GEMM2, and accumulation only for experts in the local 32-expert window.

CUTLASS/CuTe headers are available under `thirdparty/` for project use. The base variant should use those headers intentionally for the two dense GEMM phases while keeping the surrounding MoE mechanics as small custom CUDA kernels.

## Goals / Non-Goals

**Goals:**

- Provide a tracked `moe-base` CUDA variant that can be registered, deployed, packed, and used as the live CUDA solution.
- Match the exact MoE TVM-FFI destination-passing signature documented for the contest contract, including `int64_t` and `double` scalar boundary types.
- Implement correctness-oriented MoE behavior with straightforward CUDA kernels around simple CUTLASS GEMM calls that future optimization work can read and modify.
- Use project-available CUTLASS/CuTe headers from `thirdparty/` without relying on ignored local checkouts, generated artifacts, FlashInfer, local install prefixes, or sidecar build machinery.

**Non-Goals:**

- Optimizing for competitive timing.
- Adding a reusable MoE framework or support for additional MoE definitions.
- Changing `project-cli` variant semantics beyond registering and stocking the new variant.
- Adding dataset-dependent checks to the default unit test path.

## Decisions

1. Implement the base kernel directly in CUDA instead of delegating to FlashInfer or a runtime sidecar. This keeps the variant self-contained and submission-shaped. The alternative, wrapping FlashInfer, would be shorter but would not exercise the CUDA TVM-FFI kernel path that this repository is meant to scaffold.

2. Use the documented ABI exactly at the exported TVM-FFI boundary: eight tensor inputs, `int64_t local_expert_offset`, `double routed_scaling_factor`, and the destination `output` tensor. Internally the scalar values can be validated and narrowed to `int32_t` and `float` because the contest geometry is fixed. The alternative, using old scratch-code scalar types, risks type mismatch with the evaluator call path.

3. Keep routing as a small per-token kernel and use intermediate workspace for `topk_idx` and `topk_weight`. This mirrors the reference and separates the easiest-to-get-wrong selection rules from the GEMM work. The alternative, fusing routing into GEMM kernels, would obscure the baseline and make correctness debugging harder.

4. Compact selected local expert slots before GEMM work. Even for a minimal kernel, computing every global top-k slot would waste most work when only 32 of 256 experts are local and would be painful on large local workloads. The compact metadata can stay simple: count local slots, write selected slot IDs and weights, run GEMM kernels only over those rows, and accumulate into a FP32 output buffer.

5. Use CUTLASS for the two dense GEMM phases, but keep the orchestration basic. Small CUDA kernels should dequantize compact activations and the needed local expert weights into CUTLASS-friendly temporary matrices, then the host path can launch simple per-expert GEMM1 and GEMM2 operations rather than a heavily fused or grouped MoE kernel. The alternative, hand-rolling scalar GEMM loops, would be easier to write but would not teach future agents how to use the project-available CUTLASS path; the opposite alternative, implementing a fully optimized grouped FP8 MoE immediately, would obscure the baseline.

6. Keep non-GEMM work in plain CUDA kernels: routing, compact-local-slot metadata, FP8 block-scale dequantization, SwiGLU, weighted accumulation, and final BF16 cast. This preserves the readability of the baseline while letting CUTLASS cover the matrix multiplication mechanics.

7. Cast the final FP32 accumulation buffer to BF16 destination output in a final kernel. This matches the reference return dtype while keeping accumulation numerically stable enough for correctness tolerance. The alternative, accumulating directly into BF16 output, would invite ordering and precision issues.

## Risks / Trade-offs

- CUTLASS setup can make a "base" kernel feel too elaborate → Limit CUTLASS usage to simple per-expert GEMM launches and keep data preparation and accumulation in short custom kernels.
- Slow large-sequence workloads → Accept as a base variant and validate correctness first on small workloads; performance work can start from this baseline later.
- High temporary memory for dequantized matrices and compact gated activations → Compacting only local slots reduces the worst waste, and implementation can fall back to CUDA allocation errors instead of silently producing wrong results.
- FP8 conversion, scale indexing, or matrix layout mistakes → Keep helper functions and indexing formulas close to the documented shapes, use explicit row-major/column-major comments around CUTLASS operands, and add validation with small local MoE workloads.
- Routing tie behavior may differ from PyTorch `topk` on exact ties → Local random and safetensor routing inputs are unlikely to produce many exact ties; if correctness exposes tie drift, adjust selection order to match observed reference behavior.
- Dataset-dependent correctness checks require CUDA and `FIB_DATASET_PATH` → Keep such checks manual or integration-level, not default unit tests.

## Migration Plan

Create the `moe-base` variant from the CUDA template, update the live `config.toml` to the exact MoE definition, implement the kernel in the live CUDA bundle, stock it back into `variants/cuda/moe-base/`, and verify the registry metadata. Rollback is restoring the previous placeholder live bundle or deploying another registered variant.

## Open Questions

None for the baseline implementation.
