"""
Pack solution source files into solution.json.

Reads configuration from config.toml and packs the appropriate source files
(Triton or CUDA) into a Solution JSON file for submission.
"""

import sys
import tomllib
from pathlib import Path

# Add project root to path for imports
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from flashinfer_bench import BuildSpec, Solution, SourceFile

VALID_SOURCE_EXTENSIONS = {".py", ".cu", ".cuh", ".cpp", ".c", ".h", ".hpp", ".inl", ".cc", ".cxx"}


def load_config() -> dict:
    """Load configuration from config.toml."""
    config_path = PROJECT_ROOT / "config.toml"
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path, "rb") as f:
        return tomllib.load(f)


def normalize_entry_point(language: str, entry_point: str) -> str:
    """Accept legacy short function names from config.toml."""
    if "::" in entry_point:
        return entry_point
    if language == "triton":
        return f"kernel.py::{entry_point}"
    if language == "cuda":
        return f"binding.py::{entry_point}"
    return entry_point


def _collect_sources_from_root(root: Path, *, prefix: Path | None = None) -> list[SourceFile]:
    """Collect source files recursively from a root using paths relative to that root."""
    if not root.exists():
        raise FileNotFoundError(f"Source/include root not found: {root}")
    if not root.is_dir():
        raise NotADirectoryError(f"Source/include root is not a directory: {root}")

    sources: list[SourceFile] = []
    for file_path in sorted(path for path in root.rglob("*") if path.is_file()):
        if file_path.suffix.lower() not in VALID_SOURCE_EXTENSIONS:
            continue
        content = file_path.read_text(encoding="utf-8")
        if not content:
            continue
        rel_path = file_path.relative_to(root)
        if prefix is not None:
            rel_path = prefix / rel_path
        sources.append(SourceFile(path=rel_path.as_posix(), content=content))
    return sources


def pack_solution_sources(source_dir: Path, dev_include_roots: list[str]) -> list[SourceFile]:
    """Pack solution sources plus development include roots into SourceFile entries."""
    sources = _collect_sources_from_root(source_dir)
    seen = {source.path for source in sources}

    for include_root in dev_include_roots:
        include_path = (PROJECT_ROOT / include_root).resolve()
        for source in _collect_sources_from_root(include_path):
            if source.path in seen:
                raise ValueError(
                    "Duplicate packed source path "
                    f"{source.path!r} from include root {include_root!r}"
                )
            seen.add(source.path)
            sources.append(source)

    if not sources:
        raise ValueError(f"No source files found in directory: {source_dir}")
    return sources


def pack_solution(output_path: Path | None = None) -> Path:
    """Pack solution files into a Solution JSON."""
    config = load_config()

    solution_config = config["solution"]
    build_config = config["build"]

    language = build_config["language"]
    entry_point = build_config["entry_point"]

    # Determine source directory based on language
    if language == "triton":
        source_dir = PROJECT_ROOT / "solution" / "triton"
    elif language == "cuda":
        source_dir = PROJECT_ROOT / "solution" / "cuda"
    else:
        raise ValueError(f"Unsupported language: {language}")

    if not source_dir.exists():
        raise FileNotFoundError(f"Source directory not found: {source_dir}")

    # Create build spec
    dps = build_config.get("destination_passing_style", True)
    spec = BuildSpec(
        language=language,
        target_hardware=["cuda"],
        entry_point=normalize_entry_point(language, entry_point),
        destination_passing_style=dps,
        binding=build_config.get("binding"),
    )

    sources = pack_solution_sources(
        source_dir,
        dev_include_roots=list(build_config.get("dev_include_roots", [])),
    )

    solution = Solution(
        spec=spec,
        name=solution_config["name"],
        definition=solution_config["definition"],
        author=solution_config["author"],
        sources=sources,
    )

    # Write to output file
    if output_path is None:
        output_path = PROJECT_ROOT / "solution.json"

    output_path.write_text(solution.model_dump_json(indent=2))
    print(f"Solution packed: {output_path}")
    print(f"  Name: {solution.name}")
    print(f"  Definition: {solution.definition}")
    print(f"  Author: {solution.author}")
    print(f"  Language: {language}")

    return output_path


def main():
    """Entry point for pack_solution script."""
    import argparse

    parser = argparse.ArgumentParser(description="Pack solution files into solution.json")
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="Output path for solution.json (default: ./solution.json)"
    )
    args = parser.parse_args()

    try:
        pack_solution(args.output)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
