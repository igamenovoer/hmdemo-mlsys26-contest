## Context

The project currently supports CUDA variants, but the CUDA scaffold is ambiguous about where the callable entry point lives. The variant template declares `binding = "tvm-ffi"` while using the short entry point `kernel`, and the pack helper maps short CUDA entry points to `binding.py::kernel`. The reference MLSys contest setup uses an explicit `kernel.cu::kernel` entry point with a TVM-FFI typed export from C++/CUDA.

This change aligns the starter kit and variant template with that reference shape while preserving the current project-cli managed file bundle of `kernel.cu` and `binding.py`.

## Goals / Non-Goals

**Goals:**

- Make CUDA solution configuration explicit about TVM-FFI by using `kernel.cu::kernel`, `binding = "tvm-ffi"`, and destination-passing style.
- Provide a CUDA template whose `kernel.cu` contains the TVM-FFI include/export structure expected by the contest builder.
- Keep `project-cli variant new`, `deploy`, `stock`, `status`, and `diff` behavior stable while updating the default CUDA metadata.
- Keep explicit `file::function` entry points untouched when packing solutions.

**Non-Goals:**

- Implement a real contest kernel or workload-specific CUDA logic.
- Add evaluation timing functionality to `project-cli`.
- Remove `binding.py` from managed CUDA bundles in this change.
- Introduce a new variant storage layout.

## Decisions

### Use `kernel.cu::kernel` as the CUDA TVM-FFI entry point

The project SHALL prefer explicit CUDA entry points for TVM-FFI variants. This avoids the legacy short-name normalization path that maps `kernel` to `binding.py::kernel`.

Alternative considered: keep `entry_point = "kernel"` and update the pack helper to infer TVM-FFI from `binding = "tvm-ffi"`. That would preserve ambiguity in the stored variant metadata and make config behavior depend on multiple fields.

### Keep `binding.py` managed but non-primary

The current variant CLI manages `kernel.cu` and `binding.py`. Keeping both files avoids a storage-layout migration and lets existing CLI status/diff/stock behavior remain understandable. The TVM-FFI callable, however, lives in `kernel.cu`.

Alternative considered: manage only `kernel.cu` for TVM-FFI variants. That is cleaner long term, but it changes the variant bundle contract more than needed for this setup.

### Put the TVM-FFI export structure in templates

The CUDA template should show the required includes, namespaced typed function, and `TVM_FFI_DLL_EXPORT_TYPED_FUNC` export. New variants should start from the same skeleton that the evaluator expects rather than a raw `__global__` placeholder.

Alternative considered: document the TVM-FFI shape only. That leaves each variant author to reconstruct the boilerplate and keeps the generated starter files misleading.

### Preserve explicit entry points in packing

The pack helper already returns explicit `file::function` values unchanged. The implementation should add or adjust tests so `kernel.cu::kernel` remains stable and is not normalized to `binding.py::kernel`.

Alternative considered: remove legacy CUDA short-name normalization. That could break existing local configs, so this change should only make the new scaffold explicit.

## Risks / Trade-offs

- Existing live config is Triton-oriented → The implementation must decide whether to switch the root `config.toml` to CUDA now or keep Triton as the default and update only CUDA scaffolds/templates. If switching, tests and docs must reflect that CUDA is now the active starter path.
- TVM-FFI headers may come from environment packages rather than this repo → The `cu130` Pixi environment and docs should make the expected dependency path clear, but this change should avoid vendoring external dependencies.
- `binding.py` remaining in the bundle can look redundant → Documentation and placeholders should state that `kernel.cu::kernel` is the primary TVM-FFI entry point.
