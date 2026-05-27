## ADDED Requirements

### Requirement: CUDA variant template uses TVM-FFI metadata
The system SHALL keep the tracked default CUDA variant template configured for TVM-FFI with `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true`.

#### Scenario: Default CUDA template manifest is TVM-FFI first
- **WHEN** a user opens `variants/templates/cuda-default/variant.toml`
- **THEN** the build metadata contains `entry_point = "kernel.cu::kernel"`.
- **AND** the build metadata contains `binding = "tvm-ffi"`.
- **AND** the build metadata contains `destination_passing_style = true`.

## MODIFIED Requirements

### Requirement: New CUDA variants are created from templates
The system SHALL create new CUDA variants by copying a tracked TVM-FFI CUDA template bundle into `variants/cuda/<variant-id>/` and registering it in `configs/variants.toml`.

#### Scenario: New variant is created
- **WHEN** a user runs `project-cli variant new moe-trial --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`
- **THEN** the CLI creates `variants/cuda/moe-trial/variant.toml`, `variants/cuda/moe-trial/kernel.cu`, and `variants/cuda/moe-trial/binding.py`.
- **AND** `variants/cuda/moe-trial/variant.toml` records `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true` when the live project is not already using CUDA.
- **AND** the CLI adds `moe-trial` to `configs/variants.toml` with the same TVM-FFI build metadata.

### Requirement: Live CUDA edits can be stocked into a variant
The system SHALL support copying the live managed CUDA bundle back into an existing registered variant while preserving the live CUDA TVM-FFI build metadata.

#### Scenario: Stock refreshes a variant
- **WHEN** a user edits `solution/cuda/kernel.cu` and runs `project-cli variant stock moe-trial`
- **THEN** the CLI copies the live `kernel.cu` and `binding.py` into `variants/cuda/moe-trial/`.
- **AND** the CLI refreshes `variants/cuda/moe-trial/variant.toml` from `config.toml`.
- **AND** the refreshed variant metadata records the live `entry_point`, `binding`, and `destination_passing_style` values.
