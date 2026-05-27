"""Placeholder helper module for CUDA TVM-FFI variants.

The configured CUDA entry point is ``kernel.cu::kernel``. Implement the TVM-FFI
typed export in ``kernel.cu``; keep this file for Python-side helpers only if a
variant needs them.
"""

ENTRY_POINT = "kernel.cu::kernel"
