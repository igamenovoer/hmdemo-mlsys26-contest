## Context

This repository uses CUDA TVM-FFI with `entry_point = "kernel.cu::kernel"` and `destination_passing_style = true`. The FlashInfer contest dataset definitions under `extern/orphan/mlsys26-contest/definitions/` define the authoritative input/output order, shapes, dtypes, and variable axes for each definition. The external CodeGandee contest notes are useful context, but this repository should verify callable contracts against the local dataset and installed `flashinfer_bench` DPS call path.

## Goals / Non-Goals

**Goals:**

- Document the MoE and DSA callable kernel contracts in a compact, implementation-ready format.
- Keep signatures aligned with local definition input/output ordering, not alphabetic JSON key dumps.
- Make the minimal runnable kernel boundary clear: TVM-FFI typed export, tensor inputs as `TensorView`, scalar floats as `double`, scalar ints as `int64_t`, outputs passed last.

**Non-Goals:**

- Do not implement kernels.
- Do not document GDN in this change.
- Do not duplicate full mathematical reference implementations.
- Do not change `config.toml` or the live CUDA bundle.

## Decisions

### Treat local definitions as the source of truth

The documentation should cite that contracts were verified against `extern/orphan/mlsys26-contest/definitions/` and the local baseline manifests, but the interface itself should be derived from the definition input/output order used by `flashinfer_bench`.

### Include signature sketches rather than full templates

The page should give C++ function signatures and enough notes to write a minimal runnable kernel. Full kernel templates belong in `solution/cuda/` or variants, not in the docs page.

## Risks / Trade-offs

- Dataset definitions can change -> state the source paths and exact definition IDs so future updates have an obvious verification target.
- A minimal callable kernel may still fail correctness -> explicitly note that timing runs only after correctness passes in the local evaluator.
