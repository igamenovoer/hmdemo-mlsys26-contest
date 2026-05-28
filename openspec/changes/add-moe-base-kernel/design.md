## Context

The repository currently has a CUDA TVM-FFI scaffold and documented contest kernel contracts, but `config.toml` still points at the coarse `fused_moe` definition and the CUDA kernel does not implement the MoE callable interface. The local contest dataset exposes the exact MoE definition `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`, where only `seq_len` varies and the evaluator calls the solution with destination-passing style inputs followed by the output tensor. Local timing is correctness-gated, so a placeholder kernel can validate build wiring but cannot produce accepted timing.

The `moe-base` implementation should be a development-oriented baseline first: it should build through the existing pack/benchmark path and may pull header-only CUTLASS/CuTe files from the ignored local checkout under `extern/orphan/cutlass`. CUDA Toolkit-provided CCCL/CUB/Thrust headers may be included directly through `nvcc`. Submission hardening can later replace the development include root with a vendored or trimmed header set if required.

## Goals / Non-Goals

**Goals:**

- Provide a registered `moe-base` CUDA variant for the exact contest MoE definition.
- Implement the TVM-FFI destination-passing signature documented in `docs/contest/kernel-contracts.md`.
- Produce numerically valid MoE outputs for local workloads before optimizing for speed.
- Use CUTLASS for GEMM1 and GEMM2, with custom CUDA kernels for routing, local expert bucketing, SwiGLU, and weighted scatter/accumulation.
- Keep dependencies header-only, and make the development packer able to include CUTLASS headers from `extern/orphan/cutlass/include`.

**Non-Goals:**

- Do not implement DSA or GDN kernels as part of this change.
- Do not pursue final contest-level performance tuning before a correct baseline exists.
- Do not introduce CMake install steps, linked CUDA libraries beyond the CUDA runtime already used by the builder, or dataset-dependent checks in the default unit test path.
- Do not depend on FlashInfer internals at solution runtime; FlashInfer and FlashInfer Bench remain references and tooling.

## Decisions

### Decision: Create `moe-base` as a project variant

`moe-base` should be managed through the existing project variant flow rather than only editing the live CUDA bundle. This keeps the baseline reproducible, allows `project-cli variant status/diff/deploy` to work, and preserves the starter-kit pattern for trying multiple kernels.

Alternative considered: edit only `solution/cuda/kernel.cu`. This is faster for a spike, but it leaves no named baseline to return to after optimization experiments.

### Decision: Match the exact contest contract in the exported kernel

The CUDA entry point should use the MoE TVM-FFI signature from the contract documentation, including `TensorView` tensor parameters, `int64_t local_expert_offset`, `double routed_scaling_factor`, and destination-passed `output`. The implementation should derive `seq_len` from tensor shapes and treat all other geometry as fixed constants for the named definition.

Alternative considered: keep a generic or coarse `fused_moe` signature. That would not match the local trace set and would fail before useful benchmarking.

### Decision: Use CUTLASS for the two GEMM stages, not for the whole MoE pipeline

The baseline should use CUTLASS grouped or blockwise FP8 GEMM for GEMM1 and GEMM2 after routing has produced local expert worklists. Routing, bucketing, SwiGLU, and scatter should remain custom CUDA kernels initially because the contest tensor layouts, block scales, and TVM-FFI packaging differ from the assumptions in the CUTLASS MoE examples.

Alternative considered: adapt `extern/orphan/cutlass/examples/92_blackwell_moe_gemm` wholesale. The examples are excellent references, but they include host-side setup patterns and layouts that are not directly the contest contract.

### Decision: Start with a multi-kernel correctness pipeline

The first baseline should use explicit intermediate buffers for top-k routing results, local expert row mappings, GEMM1 output, SwiGLU output, GEMM2 output, and final scatter. This gives each stage a debuggable boundary and makes it easier to compare against the PyTorch reference. Later changes can fuse epilogues or eliminate buffers once correctness is stable.

Alternative considered: fuse routing, GEMM epilogues, activation, and scatter from the beginning. That may reduce memory traffic but would make the hardest correctness issues harder to isolate.

### Decision: Use a development CUTLASS include root before vendoring

The implementation may use `extern/orphan/cutlass/include` as a development include root. The packer should recursively include files from that root into `solution.json` using paths such as `cutlass/...` and `cute/...`, because the TVM-FFI builder only includes the unpacked solution build directory. This avoids patching the installed FlashInfer Bench builder and lets normal CUTLASS includes work in local development.

Alternative considered: vendor CUTLASS headers into the tracked solution tree immediately. That is more submission-like, but it adds bulk before the correct CUTLASS kernel shape is known.

## Risks / Trade-offs

- CUTLASS block-scale layout mismatch → Mitigate by first validating one GEMM shape and scale mapping against a small local workload before wiring the full pipeline.
- Scratch memory can become large for long `seq_len` workloads → Mitigate by sizing buffers from `seq_len` and local selected-token count, then reduce storage after correctness by fusing stages or using narrower intermediates where tolerance permits.
- Routing correctness is easy to subtly break → Mitigate by implementing the DeepSeek-style selection exactly: biased scores select experts, unbiased sigmoid scores produce normalized weights, and `routed_scaling_factor` is applied after normalization.
- Multiple selected local experts per token require accumulation → Mitigate by using a deterministic scatter/accumulate strategy that clears output first and accumulates all local expert contributions before returning.
- Development packing of CUTLASS can bloat `solution.json` → Mitigate by accepting broad headers during development and trimming or vendoring intentionally after the correct GEMM path is stable.
- Large workloads may expose slow routing or bucketing stages → Mitigate by treating `moe-base` as the stable baseline and leaving aggressive routing/bucketing optimization to later variants.

## Migration Plan

Create the `moe-base` variant, align its `variant.toml` and deployable config with the exact MoE definition, configure the development packer to include CUTLASS headers from `extern/orphan/cutlass/include`, implement the staged kernel pipeline, then validate with pack/build and CUDA-backed local benchmark runs. Rollback is to deploy the prior stock CUDA scaffold or another registered variant and leave `moe-base` as an isolated variant for further fixes.

## Open Questions

- Which CUTLASS GEMM interface gives the cleanest match for the contest FP8 block-scale tensors: grouped blockwise GEMM, MoE grouped GEMM plus custom scale handling, or an initial dequantizing baseline followed by non-blockscaled CUTLASS GEMM?
- Should the first correctness baseline accumulate final output in float scratch before converting to bfloat16, or accumulate directly in bfloat16/atomic form to reduce scratch memory?
- What packed-size threshold is acceptable if the development packer includes a broad CUTLASS header subset for the first working baseline?
