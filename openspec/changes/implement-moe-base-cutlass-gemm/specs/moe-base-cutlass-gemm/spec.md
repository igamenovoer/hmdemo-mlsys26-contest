## ADDED Requirements

### Requirement: CUTLASS GEMM Layout Validation
The `moe-base` implementation SHALL validate the selected CUTLASS GEMM operand and scale layouts against the contest MoE tensor contract before using the fast path for official validation.

#### Scenario: GEMM1 layout is validated
- **WHEN** the developer enables the CUTLASS GEMM1 path for a small MoE workload
- **THEN** the implementation compares GEMM1 output or final output against the existing naive path for the same local expert rows.
- **AND** the comparison documents how `hidden_states_scale` and `gemm1_weights_scale` map to the selected CUTLASS scale layout.

#### Scenario: GEMM2 layout is validated
- **WHEN** the developer enables the CUTLASS GEMM2 path for a small MoE workload
- **THEN** the implementation compares GEMM2 output or final output against the existing naive path for the same activated local expert rows.
- **AND** the comparison documents how `gemm2_weights_scale` maps to the selected CUTLASS scale layout.

### Requirement: Real-Compute Timing Path
The `moe-base` official validation path SHALL report timing for real GEMM computation rather than replaying cached final outputs.

#### Scenario: Output cache is disabled for official timing
- **WHEN** the developer runs the official local MoE evaluation command for this change
- **THEN** the normal `moe-base` path does not satisfy timed iterations by copying from a final-output cache keyed by inputs.
- **AND** the resulting output still satisfies the contest correctness thresholds.

#### Scenario: Development fallback is explicit
- **WHEN** a naive fallback or output-cache comparison mode remains available for debugging
- **THEN** it is guarded or documented as a development mode.
- **AND** nearby documentation does not present that mode as the real performance baseline.

### Requirement: CUTLASS GEMM Integration
The `moe-base` implementation SHALL provide an `sm_100a` CUTLASS-backed or `sm_100a` CUTLASS-bridged GEMM path for compact local expert rows while preserving the existing contest MoE semantics.

#### Scenario: GEMM1 computes compact local rows
- **WHEN** compact local expert rows are available after routing and bucketing
- **THEN** GEMM1 computes a `[local_rows, 4096]` intermediate for those rows using an `sm_100a` CUTLASS-backed or `sm_100a` CUTLASS-bridged implementation.
- **AND** routing order, local expert IDs, and per-row weights remain unchanged.

#### Scenario: GEMM2 computes and scatters local contributions
- **WHEN** SwiGLU activation is available for compact local expert rows
- **THEN** GEMM2 computes each row's `[7168]` expert output using an `sm_100a` CUTLASS-backed or `sm_100a` CUTLASS-bridged implementation.
- **AND** weighted accumulation into the destination output preserves the local-expert-only contest semantics.

### Requirement: Official Evaluation Evidence
The project SHALL record build, correctness, and official local evaluation evidence for the real-compute `moe-base` path.

#### Scenario: Developer validates the implemented path
- **WHEN** the implementation is ready for evaluation
- **THEN** the developer runs `pixi run pack`, a CUDA 13 compile/build check, and the official local MoE evaluation command against `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- **AND** the validation is run only on an idle GPU with enough memory.

#### Scenario: Documentation reflects current limitations
- **WHEN** the implementation still has limitations such as dequantized scratch, partial CUTLASS coverage, or a debug fallback
- **THEN** `docs/contest/moe-base.md` records those limitations and distinguishes them from the validated timing path.
