from scripts.pack_solution import normalize_entry_point


def test_normalize_entry_point_keeps_explicit_path() -> None:
    assert normalize_entry_point("triton", "custom.py::run") == "custom.py::run"


def test_normalize_entry_point_supports_legacy_triton_name() -> None:
    assert normalize_entry_point("triton", "kernel") == "kernel.py::kernel"


def test_normalize_entry_point_supports_legacy_cuda_name() -> None:
    assert normalize_entry_point("cuda", "kernel") == "binding.py::kernel"
