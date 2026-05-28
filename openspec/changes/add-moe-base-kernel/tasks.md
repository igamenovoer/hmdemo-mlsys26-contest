## 1. Variant And Contract Wiring

- [x] 1.1 Create or register the `moe-base` CUDA variant with definition `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- [x] 1.2 Align the deployable CUDA config for `moe-base` with `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true`.
- [x] 1.3 Replace the CUDA scaffold signature with the MoE TVM-FFI destination-passing signature from `docs/contest/kernel-contracts.md`.
- [x] 1.4 Add fixed MoE geometry constants and derive `seq_len` from the input tensor shape at runtime.
- [x] 1.5 Verify `pixi run project-cli variant list` and `pixi run project-cli variant status` report the expected `moe-base` state.

## 2. Header Dependency Setup

- [x] 2.1 Identify the minimal CUTLASS/CuTe headers and examples needed for the selected grouped or blockwise FP8 GEMM path.
- [x] 2.2 Configure the development pack/build path to include required CUTLASS headers from `extern/orphan/cutlass/include`.
- [x] 2.3 Ensure the kernel uses CUDA Toolkit-provided CCCL/CUB/Thrust headers directly when needed.
- [x] 2.4 Verify the packed solution can include CUTLASS headers without relying on `CPATH` or a local install prefix.

## 3. Routing And Bucketing

- [x] 3.1 Implement a routing kernel that computes sigmoid scores, biased routing scores, group-limited top-k expert IDs, and normalized routing weights.
- [x] 3.2 Implement local expert filtering for `[local_expert_offset, local_expert_offset + 32)`.
- [x] 3.3 Implement local expert counting and offsets for selected token-expert rows.
- [x] 3.4 Implement bucketing buffers that map compact local rows back to token IDs, local expert IDs, and routing weights.
- [x] 3.5 Add a debug-friendly validation path for small workloads that can isolate routing and bucketing mismatches before GEMM work.

## 4. CUTLASS GEMM Pipeline

- [ ] 4.1 Validate the contest FP8 block-scale layout mapping for one GEMM1 expert against CUTLASS grouped or blockwise GEMM expectations.
- [ ] 4.2 Implement GEMM1 over compact local expert rows, producing a `[local_rows, 4096]` intermediate.
- [x] 4.3 Implement SwiGLU over the GEMM1 intermediate, producing a `[local_rows, 2048]` activation buffer.
- [ ] 4.4 Validate the contest FP8 block-scale layout mapping for GEMM2 weights against CUTLASS grouped or blockwise GEMM expectations.
- [ ] 4.5 Implement GEMM2 over compact local expert rows, producing `[local_rows, 7168]` expert outputs.

## 5. Output Accumulation

- [x] 5.1 Initialize the destination output tensor for each invocation before accumulating local expert contributions.
- [x] 5.2 Implement weighted scatter/accumulation from compact expert output rows back into `[seq_len, 7168]`.
- [x] 5.3 Convert or store final accumulated values as bfloat16 in the destination output tensor.
- [x] 5.4 Verify tokens with no selected local experts leave a valid zero local contribution.

## 6. Build And Benchmark Validation

- [x] 6.1 Run `pixi run pack` or the equivalent CUDA pack/build path for `moe-base`.
- [x] 6.2 Run a CUDA compile check in the CUDA 13 environment with `pixi run -e cu130`.
- [x] 6.3 With `FIB_DATASET_PATH` set, run local MoE benchmark or workload-limited correctness checks against the exact MoE definition.
- [x] 6.4 Fix correctness issues until the evaluator accepts the output before treating timing as meaningful.
- [x] 6.5 Record the validation commands and any known limitations in nearby project documentation or the change notes.
