"""
Placeholder for Python-controlled CUDA bindings.

The default CUDA template exports a TVM-FFI symbol directly from kernel.cu, so
this module is unused unless a variant deliberately moves to a Python-managed
binding path.
"""


def run(*_args, **_kwargs):
    """Placeholder binding for a new CUDA variant template."""
    raise NotImplementedError("TODO: implement this variant's binding.py::run")
