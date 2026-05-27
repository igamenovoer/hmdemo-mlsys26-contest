# cuda-tvm-ffi-solution Specification

## Purpose
Defines the CUDA solution scaffold and packable configuration expectations for TVM-FFI CUDA solutions.

## Requirements
### Requirement: CUDA solution config targets TVM-FFI
The project CUDA solution configuration SHALL identify the CUDA source entry point explicitly as `kernel.cu::kernel` and SHALL use `binding = "tvm-ffi"` with destination-passing style enabled.

#### Scenario: CUDA config is packable as TVM-FFI
- **WHEN** the project is configured for `language = "cuda"`
- **THEN** `config.toml` contains `entry_point = "kernel.cu::kernel"`.
- **AND** `config.toml` contains `binding = "tvm-ffi"`.
- **AND** `config.toml` contains `destination_passing_style = true`.

### Requirement: CUDA kernel scaffold exports a TVM-FFI function
The CUDA kernel scaffold SHALL expose the configured entry point from `solution/cuda/kernel.cu` using a TVM-FFI typed export.

#### Scenario: CUDA scaffold contains TVM-FFI export
- **WHEN** a user opens `solution/cuda/kernel.cu`
- **THEN** the file includes the TVM-FFI headers needed for typed tensor/function bindings.
- **AND** the file exports the `kernel` symbol with `TVM_FFI_DLL_EXPORT_TYPED_FUNC`.

### Requirement: CUDA Python binding file is not the primary TVM-FFI entry point
The CUDA solution bundle SHALL keep `solution/cuda/binding.py` as a placeholder or helper file while making `solution/cuda/kernel.cu` the primary configured TVM-FFI entry point.

#### Scenario: Binding placeholder points users to kernel.cu
- **WHEN** a user opens `solution/cuda/binding.py`
- **THEN** the file indicates that TVM-FFI CUDA variants use `kernel.cu::kernel` as the configured entry point.

### Requirement: Pack helper preserves explicit CUDA source entry points
The solution pack helper SHALL preserve explicit CUDA entry points that already use `file::function` syntax.

#### Scenario: Explicit CUDA entry point is preserved
- **WHEN** the pack helper normalizes `language = "cuda"` and `entry_point = "kernel.cu::kernel"`
- **THEN** it returns `kernel.cu::kernel`.
