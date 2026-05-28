## 1. Baseline Mapping

- [x] 1.1 Confirm the current `moe-base` variant and live CUDA bundle target the exact MoE definition and TVM-FFI destination-passing signature.
- [x] 1.2 Extract the FlashInfer baseline wrapper constants, tensor layout assumptions, routing mode, weight layout, activation, and output dtype into implementation notes or nearby MoE documentation.
- [x] 1.3 Mark the generic CUTLASS bridge direction as superseded for `moe-base` by updating relevant docs or change notes without deleting unrelated prior work.
- [x] 1.4 Audit the existing output-cache replay and GEMM mode switches so the official validation path is clearly real-compute only.

## 2. Source-Packable Structure

- [x] 2.1 Choose the minimal FlashInfer source references to adapt for DeepSeekV3 routing, activation, and finalize semantics.
- [x] 2.2 Choose the CUTLASS/CuTe Blackwell GEMM reference path for GEMM1 and GEMM2, including whether the first milestone uses native block-scale GEMM or a dequantized CUTLASS bridge.
- [x] 2.3 Add solution-local helper files or tracked headers needed by `moe-base`, keeping ignored `extern/orphan/` checkouts as references only.
- [x] 2.4 Update packer/config/compiler flags only as needed so the packed solution can build required source-packable headers for `sm_100a`.

## 3. Routing And Workspace

- [x] 3.1 Implement fixed-geometry shape and dtype validation for the MoE contract inside the CUDA entry path.
- [x] 3.2 Implement or adapt DeepSeekV3 grouped routing with biased sigmoid scores for selection and normalized unbiased sigmoid scores for routed weights.
- [x] 3.3 Implement local expert filtering using `local_expert_offset` and the local expert count derived from `gemm1_weights`.
- [x] 3.4 Allocate or reuse scratch workspace for routing outputs, local row maps, GEMM intermediates, activation output, and finalize metadata.

## 4. GEMM And Finalize

- [x] 4.1 Implement scale-layout handling for `hidden_states_scale`, `gemm1_weights_scale`, and `gemm2_weights_scale` against the selected GEMM adapter.
- [x] 4.2 Implement GEMM1 for compact local rows and validate its output against the existing naive arithmetic path on small workloads.
- [x] 4.3 Implement Swiglu activation over GEMM1 output with the same gated layout expected by the FlashInfer baseline.
- [x] 4.4 Implement GEMM2 for activated local rows and validate its output against the existing naive arithmetic path on small workloads.
- [x] 4.5 Implement weighted finalize into the destination-passed bfloat16 output and ensure non-local expert contributions are excluded.

## 5. Validation

- [x] 5.1 Run `pixi run pack` and the CUDA 13.0 TVM-FFI build path for the packed `moe-base` solution.
- [x] 5.2 Run fast non-GPU checks affected by the packaging or variant changes, including unit tests for the packer or project CLI when touched.
- [x] 5.3 Run correctness-gated MoE evaluation by the official local method with output-cache replay disabled.
- [x] 5.4 Before any GPU benchmark, check for an idle GPU with enough VRAM and near-idle SM utilization; wait if none is available.
- [x] 5.5 Update `docs/contest/moe-base.md` or nearby documentation with the final baseline mapping, selected implementation references, validation command, result, and remaining limitations.
- [x] 5.6 Run `openspec validate port-flashinfer-moe-baseline` and confirm all artifacts remain consistent.
