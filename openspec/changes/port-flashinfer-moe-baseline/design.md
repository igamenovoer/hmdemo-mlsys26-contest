## Context

The local contest baseline for `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` is `extern/orphan/mlsys26-contest/solutions/baseline/moe/.../flashinfer_wrapper_9sdjf3.json`. Its `main.py` normalizes scalar inputs and contiguous tensors, then calls `flashinfer.fused_moe.trtllm_fp8_block_scale_moe` with `NUM_EXPERTS_GLOBAL=256`, `TOP_K=8`, `N_GROUP=8`, `TOPK_GROUP=4`, `INTERMEDIATE_SIZE=2048`, `routing_method_type=2`, and `use_shuffled_weight=False`.

Our CUDA path must instead expose `kernel.cu::kernel` through TVM-FFI with destination-passing style. The contract in `docs/contest/kernel-contracts.md` passes the ten MoE inputs in definition order and a bfloat16 output tensor at the end. The fixed geometry matches the FlashInfer wrapper: hidden size 7168, local expert count 32, GEMM1 output 4096, GEMM2 intermediate 2048, FP8 E4M3 operands, and FP32 block scales with 128-element scale blocks.

The exact FlashInfer fast path is not a small header-only dependency. `trtllm_fp8_block_scale_moe` eventually uses FlashInfer/TensorRT-LLM generated batched GEMM machinery, downloaded `trtllmGen_bmm_export` headers, and cubin artifact plumbing. That makes direct runtime reuse unsuitable for a minimal packed CUDA submission. However, `extern/orphan/flashinfer` still gives excellent source references for the required dataflow: DeepSeekV3 routing, routing metadata, activation, finalize, and TensorRT-LLM runner semantics. CUTLASS under `extern/orphan/cutlass` gives source references for Blackwell FP8 block-scale GEMM and grouped MoE GEMM.

Dataflow target:

```text
TVM-FFI DPS kernel
  -> validate fixed MoE contract shape/dtype assumptions
  -> DeepSeekV3 grouped routing: sigmoid logits, bias for expert selection, unbiased sigmoid weights normalized and scaled
  -> compact local expert work for experts in [local_expert_offset, local_expert_offset + local_num_experts)
  -> FP8 block-scale GEMM1 in MajorK weight layout
  -> Swiglu activation
  -> FP8 block-scale GEMM2 in MajorK weight layout
  -> weighted finalize into destination-passed bfloat16 output
```

## Goals / Non-Goals

**Goals:**

- Implement `moe-base` according to the FlashInfer baseline semantics while preserving the contest TVM-FFI destination-passing interface.
- Use source-packable CUDA/CUTLASS/CuTe code paths for the stages needed by the packed solution.
- Keep `sm_100a` as the target architecture and avoid lower-architecture fallback designs.
- Make correctness the first milestone, then use official correctness-gated timing with output-cache replay disabled.
- Keep reference-only code under `extern/orphan/` out of final runtime assumptions.

**Non-Goals:**

- Do not depend on installed FlashInfer Python, `flashinfer-cubin`, FlashInfer JIT downloads, TensorRT-LLM generated cubin loading, local install prefixes, or runtime `CPATH`.
- Do not implement DSA, GDN, or other contest definitions in this change.
- Do not attempt final contest-level fusion or autotuning before the baseline path is correct and timed as real compute.
- Do not continue the SM80 or generic CUTLASS GEMM bridge direction for `moe-base`.

## Decisions

### Decision: Treat the FlashInfer wrapper as the semantic adapter

The CUDA entry point should mirror the wrapper constants and assumptions rather than rediscovering the contract from the PyTorch reference. It should derive `seq_len` and `local_num_experts` from tensor shapes, use fixed constants for global experts/top-k/groups/intermediate size, and preserve MajorK weight layout and Swiglu semantics.

Alternative considered: keep the existing naive pipeline as the semantic reference. That helped validate the TVM-FFI contract, but it is not the contest baseline core and it led us toward optimizing the wrong abstraction.

### Decision: Use FlashInfer native sources as references, not as runtime dependencies

The implementation should read from `extern/orphan/flashinfer` for algorithms and shape rules, especially `fused_moe/noAuxTcKernels.cu`, `fused_moe/trtllm_backend/*`, `trtllm_fused_moe_kernel_launcher.cu`, and `trtllm_fused_moe_runner.cu`. It should only copy or adapt the small source-packable portions needed into tracked solution files if their licenses and dependency surface are acceptable.

Alternative considered: vendor the entire `trtllm_fp8_block_scale_moe` launcher stack. That path is coupled to generated BMM headers and cubin artifact loading, which is likely too large and fragile for the contest solution pack.

### Decision: Split the first implementation into debuggable MoE stages

The first corrected baseline should keep explicit stage boundaries for routing, local work compaction, GEMM1, activation, GEMM2, and finalize. This lets us validate the baseline mapping against small workloads and compare intermediates before pursuing fused epilogues.

Alternative considered: port a fully fused MoE runner immediately. That would be closer to FlashInfer performance, but failure modes would blend routing, scale layout, GEMM, activation, and finalize errors into one debugging surface.

### Decision: Use CUTLASS/CuTe for GEMM stages through a source-packable adapter

GEMM1 and GEMM2 should be implemented with CUTLASS/CuTe Blackwell APIs where practical. The target is native FP8 block-scale GEMM over the contest layouts; an intermediate dequantized CUTLASS bridge is acceptable only if it performs real arithmetic during timing, remains `sm_100a`-oriented, and is clearly documented as a stepping stone.

Alternative considered: use FlashInfer's TensorRT-LLM generated BMM runner. It is the baseline's production fast path, but it requires generated artifacts that are not present as simple repository headers.

### Decision: Make packaging intentional

Any helper headers, copied source references, or CUTLASS include roots needed for the built solution must be included through the packer or tracked solution-local files. The final packed solution must build from its sources without assuming ignored `extern/orphan/` checkouts exist on the evaluator.

Alternative considered: rely on broad local include paths during evaluation. That works only on this development machine and contradicts the project guardrails for `extern/orphan/`.

### Decision: Retire output-cache replay from validation

The existing output-cache mechanism may remain only as a temporary development comparison aid behind a disabled guard. Official validation for this change must run the real MoE arithmetic path during timed iterations.

Alternative considered: keep cache replay as a fallback for large workloads. That would hide incomplete GEMM work and make timing results untrustworthy.

## Risks / Trade-offs

- FlashInfer generated BMM behavior may be hard to match exactly -> Mitigate by first matching wrapper-level semantics and evaluator correctness, then compare against FlashInfer/PyTorch references on selected workloads.
- CUTLASS block-scale layout may not match contest scale tensors directly -> Mitigate with a dedicated scale-layout adapter or an explicitly documented dequantized bridge before native block-scale integration.
- Solution packing may become large if broad CUTLASS headers are bundled -> Mitigate by starting broad for development, then trimming to the needed header subset once the working GEMM path is known.
- Multi-kernel staged implementation may be slower than FlashInfer baseline -> Mitigate by treating this as a correctness-first real-compute baseline and leaving fusion/autotuning to follow-up variants.
- GPU availability may delay official runs -> Mitigate by checking GPU memory and SM utilization and waiting for an idle GPU before local evaluation.

## Migration Plan

First mark the generic CUTLASS bridge change as superseded in working notes or leave it inactive while this change becomes the implementation source of truth. Next adapt the live `moe-base` variant around the FlashInfer-baseline dataflow, preserving the existing TVM-FFI contract. Add or vendor any source-packable routing/GEMM helper code intentionally, then run pack/build checks and correctness-gated local workloads. When representative correctness passes, run official evaluation on an idle `sm_100a` GPU with cache replay disabled. Rollback is to redeploy the previous `moe-base` variant revision or compile-time select the naive correctness path while keeping the FlashInfer-baseline adapter disabled.

## Open Questions

- Which CUTLASS Blackwell interface is the smallest viable source-packable match for the contest FP8 block-scale GEMM layouts?
- How much FlashInfer routing/finalize source should be copied versus reimplemented from the algorithmic reference?
- Should the first real-compute milestone use native FP8 block-scale GEMM immediately, or use a dequantized CUTLASS bridge to isolate routing/finalize correctness before optimizing scales?
