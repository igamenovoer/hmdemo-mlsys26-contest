## Context

`moe-base` currently has the exact contest TVM-FFI interface, routing, local expert bucketing, naive GEMM1, SwiGLU, naive GEMM2, weighted scatter, and bfloat16 output storage. It passes the local official MoE workload set only because the benchmark timing phase reuses outputs through a sampled content-fingerprint cache after the correctness pass computes exact results. FlashInfer Bench intentionally clones tensor arguments before timing, so pointer caching is ineffective and the sampled cache is only a development bridge, not a real kernel optimization.

The contest tensors are FP8 E4M3 with explicit FP32 block scales. GEMM1 logically computes `[local_rows, 7168] x [7168, 4096] -> [local_rows, 4096]`, with `hidden_states_scale` shaped `[56, seq_len]` and `gemm1_weights_scale` shaped `[32, 32, 56]`. GEMM2 logically computes `[local_rows, 2048] x [2048, 7168] -> [local_rows, 7168]`, with `gemm2_weights_scale` shaped `[32, 56, 16]`. CUTLASS examples under `extern/orphan/cutlass/examples/81_blackwell_gemm_blockwise/` and `extern/orphan/cutlass/examples/92_blackwell_moe_gemm/` show the relevant Blackwell FP8 blockwise and MoE grouped APIs, but their host-side setup and interleaved scale layouts do not directly match the contest TVM-FFI contract. The target architecture is `sm_100a`; compatibility fallbacks using SM80 or SM90 kernels are out of scope for `moe-base`.

## Goals / Non-Goals

**Goals:**

- Introduce a real `sm_100a` GEMM path that does arithmetic during timed iterations, not output-cache replay.
- Validate the contest FP8 block-scale layout against the selected CUTLASS scale layout before enabling the fast path.
- Keep routing, local expert filtering, bucketing, SwiGLU, weighted scatter, output dtype, and destination-passing interface stable.
- Preserve a compile-time or development fallback to the naive path for comparison while the CUTLASS path is being integrated.
- Validate with the official local MoE evaluation command on idle GPUs only.

**Non-Goals:**

- Do not implement DSA or GDN kernels.
- Do not add non-header-only CUDA dependencies, CMake install requirements, reliance on `extern/orphan/` at runtime outside the existing pack-time header flow, or lower-architecture CUTLASS fallbacks such as SM80.
- Do not claim final contest performance; this change targets a correct, real-compute baseline that can be optimized further.
- Do not change the contest kernel contract or the registered `moe-base` definition.

## Decisions

### Decision: Treat scale mapping as the first deliverable

The first implementation step is to encode and test the mapping from contest scale tensors to CUTLASS scale expectations for one local expert and one small workload. For GEMM1, A scales are per `[token, hidden_block]` but provided as `[hidden_block, token]`, and B scales are per `[out_block, hidden_block]`. For GEMM2, B scales are per `[hidden_block, intermediate_block]`. The design should either prove that CUTLASS can consume a transformed scratch scale layout or explicitly fall back to a dequantized CUTLASS GEMM while the native block-scale path remains pending.

Alternative considered: wire the full grouped GEMM example immediately. That risks conflating pointer-array setup, scale interleaving, row bucketing, and numerical errors in one large failure.

### Decision: Use an incremental adapter around the existing staged pipeline

Keep the current staged buffers and swap one GEMM stage at a time behind small host-side helper functions. The sequence is GEMM1 adapter first, compare against the naive GEMM1 output on small work, then GEMM2 adapter, then remove the output cache once official timing no longer depends on it.

Alternative considered: rewrite the whole kernel around CUTLASS MoE grouped examples. The examples are useful references, but preserving the existing staged pipeline makes correctness regressions easier to isolate.

### Decision: Prefer grouped/ragged contiguous CUTLASS shape, but allow only an SM100a dequantized CUTLASS bridge

The target path is CUTLASS grouped or ragged contiguous GEMM with `cutlass::float_e4m3_t` operands and Blackwell scale support. If native block-scale layout integration is blocked, an intermediate bridge may dequantize compact A/B tiles into scratch and run a CUTLASS GEMM only if the kernel is still built for `sm_100a` through CUTLASS 3 collectives. A lower-architecture bridge would hide the real integration problem and is not acceptable for this change.

Alternative considered: keep the naive CUDA GEMMs until native block-scale grouped GEMM is perfect. That keeps correctness simple but does not advance toward a trustworthy timing baseline.

### Decision: Remove cache from official validation once real GEMM timing passes

The sampled content-fingerprint output cache may remain temporarily behind a development guard while comparing outputs, but official validation for this change must run with cache replay disabled or removed. The docs must distinguish comparison aids from the actual benchmarked path.

Alternative considered: leave the cache active as a fallback for large workloads. That undermines timing interpretation and makes it too easy to hide incomplete GEMM work.

## Risks / Trade-offs

- CUTLASS scale layouts may require interleaved scratch transforms → Mitigate by implementing scale-layout probes and keeping the naive per-stage comparison path until one GEMM is numerically validated.
- CUTLASS template compile time and packed header size may become painful → Mitigate by starting with one or two fixed geometry instantiations for the exact contest shape and preserving the existing broad development include root only during local development.
- Dequantized bridge may be slower or memory-heavy → Mitigate by treating it as a temporary real-compute baseline and documenting memory use separately from the target native FP8 block-scale path.
- Output tolerance may hide some approximate errors → Mitigate by comparing intermediate GEMM outputs against the naive path on small workloads before relying only on final `matched_ratio`.
- GPU availability can delay official runs → Mitigate by checking `nvidia-smi` and using only idle GPUs with enough memory, as required by project workflow.

## Migration Plan

First add helper documentation and compile-time flags for `moe-base` GEMM modes. Next implement the GEMM1 layout probe and a minimal CUTLASS or dequantized-CUTLASS adapter, then validate against the naive GEMM1 on a small local workload. Repeat for GEMM2 and final scatter. Once the real-compute path passes representative correctness, disable the output cache for official validation and run the full MoE evaluation command on an idle GPU. Rollback is to deploy the previous `moe-base` variant revision or re-enable the naive path while keeping the CUTLASS helpers disabled.

## Open Questions

- Can the contest `hidden_states_scale`, `gemm1_weights_scale`, and `gemm2_weights_scale` tensors be transformed cheaply enough into CUTLASS SM100 block-scale layouts per invocation?
- Does a native grouped/ragged contiguous CUTLASS launch fit cleanly inside the TVM-FFI built shared object without extra host registration or persistent workspace?
- Is the dequantized CUTLASS bridge fast enough to pass official timing without cache replay, or should it be used only as a stepping stone to native FP8 block-scale CUTLASS?
