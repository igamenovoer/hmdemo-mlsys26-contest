# moe-base-cuda-variant Specification

## Purpose
TBD - created by archiving change add-moe-base-cuda-variant. Update Purpose after archive.
## Requirements
### Requirement: Moe Base Variant Registration

The repository SHALL provide a registered CUDA variant named `moe-base` that targets the exact MoE contest definition `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.

#### Scenario: Variant appears in registry

- **WHEN** a user runs `pixi run project-cli variant list`
- **THEN** the output includes `moe-base` as a CUDA variant for `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`

#### Scenario: Variant metadata uses TVM-FFI destination passing

- **WHEN** a user opens `variants/cuda/moe-base/variant.toml`
- **THEN** it records `entry_point = "kernel.cu::kernel"`
- **AND** it records `binding = "tvm-ffi"`
- **AND** it records `destination_passing_style = true`

### Requirement: Moe Base Live CUDA Configuration

The live CUDA solution configuration SHALL be deploy-compatible with the `moe-base` variant and SHALL use the exact MoE contest definition rather than a coarse track alias.

#### Scenario: Live config targets exact MoE definition

- **WHEN** a user opens `config.toml`
- **THEN** `[solution].definition` is `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`
- **AND** `[build].language` is `cuda`
- **AND** `[build].entry_point` is `kernel.cu::kernel`
- **AND** `[build].binding` is `tvm-ffi`
- **AND** `[build].destination_passing_style` is `true`

#### Scenario: Variant deploy accepts live config

- **WHEN** a user runs `pixi run project-cli variant deploy moe-base`
- **THEN** the command succeeds without reporting live config metadata mismatches

### Requirement: Moe Base TVM-FFI Kernel Contract

The `moe-base` CUDA kernel SHALL export the documented MoE TVM-FFI destination-passing function and SHALL consume all tensors and scalars in definition order.

#### Scenario: Kernel exports typed function

- **WHEN** a user opens `variants/cuda/moe-base/kernel.cu`
- **THEN** the file exports the `kernel` symbol with `TVM_FFI_DLL_EXPORT_TYPED_FUNC`

#### Scenario: Kernel signature matches documented contract

- **WHEN** the evaluator invokes `kernel.cu::kernel` for `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`
- **THEN** the callable accepts `routing_logits`, `routing_bias`, `hidden_states`, `hidden_states_scale`, `gemm1_weights`, `gemm1_weights_scale`, `gemm2_weights`, `gemm2_weights_scale`, `local_expert_offset`, `routed_scaling_factor`, and `output` in that order
- **AND** tensor arguments use `tvm::ffi::TensorView`
- **AND** `local_expert_offset` uses the TVM-FFI scalar boundary type `int64_t`
- **AND** `routed_scaling_factor` uses the TVM-FFI scalar boundary type `double`

### Requirement: Moe Base Correctness Semantics

The `moe-base` CUDA kernel SHALL compute the MoE output according to the local definition reference for the fixed DeepSeek geometry and variable `seq_len`.

#### Scenario: Routing follows no-aux top-k behavior

- **WHEN** the kernel processes one token's routing inputs
- **THEN** it computes sigmoid scores from `routing_logits`
- **AND** it adds `routing_bias` only for group and expert selection
- **AND** it selects top-4 groups using the sum of top-2 biased scores per group
- **AND** it selects top-8 experts from the selected groups using biased scores
- **AND** it normalizes un-biased sigmoid scores for the selected experts and multiplies by `routed_scaling_factor`

#### Scenario: Local expert compute follows FP8 block-scale MoE reference

- **WHEN** a selected expert falls within `[local_expert_offset, local_expert_offset + 32)`
- **THEN** the kernel dequantizes `hidden_states`, `gemm1_weights`, and `gemm2_weights` with their documented 128-element block scales
- **AND** it computes GEMM1, applies SwiGLU over the two intermediate halves, computes GEMM2, and accumulates the weighted contribution into the token output

#### Scenario: Dense GEMMs use basic CUTLASS calls

- **WHEN** the kernel computes GEMM1 or GEMM2 for compact local expert work
- **THEN** the implementation uses project-available CUTLASS/CuTe headers from `thirdparty/` for the dense matrix multiplication step
- **AND** surrounding routing, dequantization, SwiGLU, local expert filtering, weighted accumulation, and final BF16 output conversion remain explicit CUDA logic in the variant
- **AND** the implementation does not require ignored `extern/orphan/` paths, local install prefixes, or `CPATH` to find CUTLASS at submission time

#### Scenario: Non-local experts do not contribute

- **WHEN** a selected expert falls outside `[local_expert_offset, local_expert_offset + 32)`
- **THEN** the kernel does not use any local weight row for that expert
- **AND** the expert contributes zero to the local output

#### Scenario: Output uses BF16 destination tensor

- **WHEN** the kernel completes accumulation for a workload
- **THEN** it writes `output` with shape `[seq_len, 7168]`
- **AND** each element is stored as `bfloat16`

### Requirement: Moe Base Validation Path

The implementation SHALL include validation steps that can be run without adding GPU or dataset-dependent work to the default unit test path.

#### Scenario: Pack and metadata checks run locally

- **WHEN** a developer validates the change on a normal development host
- **THEN** they can run non-dataset checks for variant metadata and packability through Pixi commands

#### Scenario: Correctness checks remain explicit

- **WHEN** a developer has CUDA and `FIB_DATASET_PATH` available
- **THEN** they can run a MoE benchmark or equivalent correctness check against `moe-base`
- **AND** that check is not required by the default `pixi run test` path

