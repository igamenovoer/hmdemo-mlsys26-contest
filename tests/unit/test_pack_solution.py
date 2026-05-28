from pathlib import Path

from scripts import pack_solution as pack_solution_module
from scripts.pack_solution import normalize_entry_point, pack_solution_sources


def test_normalize_entry_point_keeps_explicit_path() -> None:
    assert normalize_entry_point("triton", "custom.py::run") == "custom.py::run"


def test_normalize_entry_point_keeps_explicit_cuda_path() -> None:
    assert normalize_entry_point("cuda", "kernel.cu::kernel") == "kernel.cu::kernel"


def test_normalize_entry_point_supports_legacy_triton_name() -> None:
    assert normalize_entry_point("triton", "kernel") == "kernel.py::kernel"


def test_normalize_entry_point_supports_legacy_cuda_name() -> None:
    assert normalize_entry_point("cuda", "kernel") == "binding.py::kernel"


def test_pack_solution_sources_adds_recursive_dev_include_roots(
    tmp_path: Path,
    monkeypatch,
) -> None:
    monkeypatch.setattr(pack_solution_module, "PROJECT_ROOT", tmp_path)
    source_dir = tmp_path / "solution/cuda"
    source_dir.mkdir(parents=True)
    (source_dir / "kernel.cu").write_text('#include <cutlass/cutlass.h>\n')
    include_root = tmp_path / "extern/orphan/cutlass/include"
    (include_root / "cutlass").mkdir(parents=True)
    (include_root / "cute").mkdir(parents=True)
    (include_root / "cutlass/cutlass.h").write_text("// cutlass header\n")
    (include_root / "cute/tensor.hpp").write_text("// cute header\n")

    sources = pack_solution_sources(source_dir, ["extern/orphan/cutlass/include"])

    assert {source.path for source in sources} == {
        "kernel.cu",
        "cutlass/cutlass.h",
        "cute/tensor.hpp",
    }
