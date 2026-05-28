"""Placeholder helper module for CUDA TVM-FFI solutions.

The configured CUDA entry point is ``kernel.cu::kernel``. Implement the TVM-FFI
typed export in ``solution/cuda/kernel.cu``; keep this file for Python-side
helpers only if a solution needs them.
"""

ENTRY_POINT = "kernel.cu::kernel"
