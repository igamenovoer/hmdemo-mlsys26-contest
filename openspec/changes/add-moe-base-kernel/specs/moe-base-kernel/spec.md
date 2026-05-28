## ADDED Requirements

### Requirement: Moe Base Variant Registration
The project SHALL provide a registered CUDA variant named `moe-base` that targets the exact contest MoE definition `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.

#### Scenario: Variant list shows moe-base
- **WHEN** a developer runs `pixi run project-cli variant list`
- **THEN** the output lists `moe-base` as a CUDA variant.
- **AND** the variant definition is `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.

#### Scenario: Moe base deploy is config-compatible
- **WHEN** a developer deploys `moe-base` with `pixi run project-cli variant deploy moe-base`
- **THEN** the deploy command succeeds when the live `config.toml` uses the same MoE definition and CUDA TVM-FFI build metadata.

### Requirement: Moe Contract Entry Point
The `moe-base` CUDA entry point SHALL implement the MoE TVM-FFI destination-passing signature documented for the contest contract.

#### Scenario: Kernel exports the configured symbol
- **WHEN** the `moe-base` CUDA source is inspected
- **THEN** it exports `kernel` with `TVM_FFI_DLL_EXPORT_TYPED_FUNC`.
- **AND** the exported function accepts the MoE input tensors in definition order followed by `local_expert_offset`, `routed_scaling_factor`, and the destination-passed `output` tensor.

#### Scenario: Kernel derives variable sequence length
- **WHEN** `moe-base` runs on MoE workloads with different `seq_len` values
- **THEN** the kernel derives the sequence length from the input tensor shapes.
- **AND** the implementation uses the fixed geometry associated with the exact MoE definition.

### Requirement: Moe Base Computes Local Expert Contributions
The `moe-base` implementation SHALL compute the local expert contribution for the contest MoE reference semantics and write the bfloat16 output tensor.

#### Scenario: Routing follows contest semantics
- **WHEN** the kernel selects experts for each token
- **THEN** biased sigmoid scores determine the selected top-k experts through the group-limited routing rule.
- **AND** unbiased sigmoid scores determine the normalized routing weights multiplied by `routed_scaling_factor`.

#### Scenario: Non-local experts are excluded
- **WHEN** selected experts fall outside `[local_expert_offset, local_expert_offset + 32)`
- **THEN** the kernel excludes those experts from local GEMM work and output accumulation.

#### Scenario: Local experts contribute through both GEMMs
- **WHEN** selected experts fall inside the local expert range
- **THEN** the kernel computes GEMM1, applies SwiGLU, computes GEMM2, weights the expert result, and accumulates it into the destination output row.

### Requirement: Moe Base Uses Development Header Dependencies
The `moe-base` implementation SHALL use only header dependencies during development and MAY use the ignored local CUTLASS checkout as a pack-time header source.

#### Scenario: CUTLASS headers are included from the development checkout
- **WHEN** the solution is packed for local development
- **THEN** any required CUTLASS headers can be sourced recursively from `extern/orphan/cutlass/include`.
- **AND** the packed source paths allow normal includes such as `#include <cutlass/...>` and `#include <cute/...>`.

#### Scenario: CCCL headers come from the CUDA Toolkit
- **WHEN** the kernel includes CUB, Thrust, or libcu++ headers
- **THEN** those headers are resolved from the CUDA Toolkit visible to `nvcc` unless a tracked vendored copy is explicitly added.

#### Scenario: Non-header CUDA libraries are not introduced
- **WHEN** `moe-base` is built through the CUDA TVM-FFI path
- **THEN** the implementation does not require new non-header-only CUDA libraries beyond the runtime/link libraries already used by the builder.

### Requirement: Moe Base Validation Path
The project SHALL document or encode the commands needed to validate `moe-base` through the existing build, pack, and benchmark path.

#### Scenario: Developer validates build and pack
- **WHEN** a developer prepares `moe-base` for evaluation
- **THEN** the documented validation path includes `pixi run pack` or an equivalent pack/build command.

#### Scenario: Developer validates correctness-gated timing
- **WHEN** a CUDA-capable environment and `FIB_DATASET_PATH` are available
- **THEN** the documented validation path includes running the local benchmark against the exact MoE definition.
