# project-cli-variants Specification

## Purpose
TBD - created by archiving change add-project-cli. Update Purpose after archive.
## Requirements
### Requirement: Project CLI exposes variant commands
The system SHALL expose a `project-cli variant` command group for managing CUDA kernel variants.

#### Scenario: Variant command group is available
- **WHEN** a user runs `project-cli variant --help`
- **THEN** the CLI lists `list`, `show`, `new`, `deploy`, `stock`, `status`, and `diff` subcommands.

### Requirement: Variant configuration is tracked
The system SHALL store shared variant registry configuration in `configs/variants.toml`.

#### Scenario: Variant list reads tracked config
- **WHEN** a user runs `project-cli variant list`
- **THEN** the CLI reads registered variants from `configs/variants.toml` and prints their IDs, language, definition, and paths.

### Requirement: Variant IDs are validated
The system SHALL require variant IDs to use lowercase kebab-case.

#### Scenario: Invalid variant ID is rejected
- **WHEN** a user runs `project-cli variant new Bad_Name --definition fused_moe`
- **THEN** the CLI fails before creating files or editing `configs/variants.toml`.

### Requirement: New CUDA variants are created from templates
The system SHALL create new CUDA variants by copying a tracked TVM-FFI CUDA template bundle into `variants/cuda/<variant-id>/` and registering it in `configs/variants.toml`.

#### Scenario: New variant is created
- **WHEN** a user runs `project-cli variant new moe-trial --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`
- **THEN** the CLI creates `variants/cuda/moe-trial/variant.toml`, `variants/cuda/moe-trial/kernel.cu`, and `variants/cuda/moe-trial/binding.py`.
- **AND** `variants/cuda/moe-trial/variant.toml` records `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true` when the live project is not already using CUDA.
- **AND** the CLI adds `moe-trial` to `configs/variants.toml` with the same TVM-FFI build metadata.

### Requirement: CUDA variant template uses TVM-FFI metadata
The system SHALL keep the tracked default CUDA variant template configured for TVM-FFI with `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true`.

#### Scenario: Default CUDA template manifest is TVM-FFI first
- **WHEN** a user opens `variants/templates/cuda-default/variant.toml`
- **THEN** the build metadata contains `entry_point = "kernel.cu::kernel"`.
- **AND** the build metadata contains `binding = "tvm-ffi"`.
- **AND** the build metadata contains `destination_passing_style = true`.

### Requirement: Variants can be deployed to the live CUDA bundle
The system SHALL deploy a stored CUDA variant by copying its managed files into `solution/cuda/`.

#### Scenario: Variant deploy updates live files
- **WHEN** a user runs `project-cli variant deploy moe-trial`
- **THEN** the CLI copies `variants/cuda/moe-trial/kernel.cu` to `solution/cuda/kernel.cu`.
- **AND** the CLI copies `variants/cuda/moe-trial/binding.py` to `solution/cuda/binding.py`.

### Requirement: Deploy validates live config compatibility
The system SHALL refuse to deploy a variant whose stored metadata conflicts with the live `config.toml`.

#### Scenario: Deploy rejects mismatched definition
- **WHEN** a stored variant targets a different definition than `config.toml`
- **THEN** `project-cli variant deploy <variant-id>` fails and reports the mismatched fields.
- **AND** the CLI does not overwrite files in `solution/cuda/`.

### Requirement: Live CUDA edits can be stocked into a variant
The system SHALL support copying the live managed CUDA bundle back into an existing registered variant while preserving the live CUDA TVM-FFI build metadata.

#### Scenario: Stock refreshes a variant
- **WHEN** a user edits `solution/cuda/kernel.cu` and runs `project-cli variant stock moe-trial`
- **THEN** the CLI copies the live `kernel.cu` and `binding.py` into `variants/cuda/moe-trial/`.
- **AND** the CLI refreshes `variants/cuda/moe-trial/variant.toml` from `config.toml`.
- **AND** the refreshed variant metadata records the live `entry_point`, `binding`, and `destination_passing_style` values.

### Requirement: Variant status reports live matches
The system SHALL compare the live managed CUDA bundle against registered variants and report exact matches.

#### Scenario: Status finds matching variant
- **WHEN** `solution/cuda/kernel.cu` and `solution/cuda/binding.py` exactly match a registered variant
- **THEN** `project-cli variant status` prints that variant ID as an exact match.

### Requirement: Variant diff compares stored and live bundles
The system SHALL show unified diffs between a registered variant and the live managed CUDA bundle.

#### Scenario: Diff shows changed file
- **WHEN** `solution/cuda/kernel.cu` differs from `variants/cuda/moe-trial/kernel.cu`
- **THEN** `project-cli variant diff moe-trial` prints a unified diff for `kernel.cu`.
