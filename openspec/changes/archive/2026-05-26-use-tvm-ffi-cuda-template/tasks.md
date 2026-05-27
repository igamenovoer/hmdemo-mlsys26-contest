## 1. CUDA TVM-FFI Scaffold

- [x] 1.1 Update `config.toml` for CUDA TVM-FFI by setting `language = "cuda"`, `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true` while preserving existing solution metadata unless a definition change is required.
- [x] 1.2 Replace `solution/cuda/kernel.cu` with a TVM-FFI scaffold that includes TVM-FFI headers, defines a typed `kernel` function, and exports it with `TVM_FFI_DLL_EXPORT_TYPED_FUNC`.
- [x] 1.3 Update `solution/cuda/binding.py` to clarify that `kernel.cu::kernel` is the primary configured TVM-FFI entry point and keep it as a placeholder/helper file.

## 2. Variant Template Updates

- [x] 2.1 Update `variants/templates/cuda-default/variant.toml` to use `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true`.
- [x] 2.2 Replace `variants/templates/cuda-default/kernel.cu` with the same TVM-FFI export-oriented scaffold pattern used by the live CUDA bundle.
- [x] 2.3 Update `variants/templates/cuda-default/binding.py` to match the non-primary binding placeholder wording.

## 3. Project CLI Behavior

- [x] 3.1 Ensure `project-cli variant new` records TVM-FFI build metadata from the default template when the live project is not already configured for CUDA.
- [x] 3.2 Ensure `project-cli variant stock` preserves live `entry_point`, `binding`, and `destination_passing_style` values in the variant manifest and `configs/variants.toml`.
- [x] 3.3 Keep variant deploy, status, and diff behavior operating over the managed `kernel.cu` and `binding.py` bundle.

## 4. Tests and Documentation

- [x] 4.1 Update unit tests that create fixture configs or template manifests so they expect `kernel.cu::kernel` for TVM-FFI CUDA variants.
- [x] 4.2 Add or update pack-helper coverage proving explicit CUDA entry points such as `kernel.cu::kernel` are preserved.
- [x] 4.3 Update relevant documentation or agent guidance that describes the CUDA/TVM-FFI entry point and the role of `binding.py`.
- [x] 4.4 Run `pixi run test` and `openspec validate use-tvm-ffi-cuda-template`.
