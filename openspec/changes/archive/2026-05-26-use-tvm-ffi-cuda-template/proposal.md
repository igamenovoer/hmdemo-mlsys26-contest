## Why

The CUDA path should match the contest-style TVM-FFI setup used by the reference project instead of routing through a Python `binding.py::kernel` placeholder. Making `kernel.cu::kernel` the explicit entry point removes ambiguity for CUDA variants and makes generated variants ready for TVM-FFI implementation work.

## What Changes

- Update the CUDA solution scaffold to use `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true`.
- Update the tracked CUDA variant template so new variants are TVM-FFI-first and export a typed function from `kernel.cu`.
- Keep `binding.py` in the managed CUDA bundle as a placeholder/helper file for compatibility with the current project-cli variant bundle.
- Update tests and documentation that currently assume a short CUDA entry point of `kernel`.

## Capabilities

### New Capabilities
- `cuda-tvm-ffi-solution`: Defines the project CUDA scaffold and packable configuration expectations for TVM-FFI CUDA solutions.

### Modified Capabilities
- `project-cli-variants`: New CUDA variants and stocked variant metadata SHALL preserve the explicit TVM-FFI entry point `kernel.cu::kernel`.

## Impact

- Affected files include `config.toml`, `solution/cuda/kernel.cu`, `solution/cuda/binding.py`, `variants/templates/cuda-default/*`, `src/hmdemo_mlsys26_contest/variants.py`, and variant-related tests.
- `scripts/pack_solution.py` should continue preserving explicit `file::function` entry points and should not normalize the TVM-FFI CUDA path back to `binding.py::kernel`.
- No default timing or evaluation CLI functionality is introduced.
