#!/usr/bin/env python3
"""Pack a repo variant directory into a FlashInfer solution JSON."""

from __future__ import annotations

import argparse
import sys
import tomllib
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT_ROOT))

from flashinfer_bench import BuildSpec, Solution, SourceFile  # noqa: E402

VALID_SOURCE_EXTENSIONS = {".py", ".cu", ".cuh", ".cpp", ".c", ".h", ".hpp", ".inl", ".cc", ".cxx"}


def load_toml(path: Path) -> dict:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def collect_sources(root: Path, *, prefix: Path | None = None) -> list[SourceFile]:
    if not root.is_dir():
        raise NotADirectoryError(f"Source root is not a directory: {root}")
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


def resolve_variant(args: argparse.Namespace) -> tuple[str, Path, dict]:
    variants = load_toml(PROJECT_ROOT / "configs" / "variants.toml").get("variants", {})
    if args.variant:
        entry = variants.get(args.variant)
        if entry is None:
            raise ValueError(f"Unknown variant id: {args.variant}")
        variant_dir = PROJECT_ROOT / "variants" / entry["path"]
        return args.variant, variant_dir, entry

    variant_dir = Path(args.path).expanduser()
    if not variant_dir.is_absolute():
        variant_dir = (PROJECT_ROOT / variant_dir).resolve()
    variant_id = args.name or variant_dir.name
    entry = {}
    manifest_path = variant_dir / "variant.toml"
    if manifest_path.exists():
        manifest = load_toml(manifest_path)
        variant_id = args.name or manifest.get("id", variant_id)
        entry.update({key: value for key, value in manifest.items() if isinstance(value, (str, bool))})
    return variant_id, variant_dir, entry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--variant", help="Registered variant id from configs/variants.toml")
    source.add_argument("--path", help="Variant directory path, relative to repo root or absolute")
    parser.add_argument("--output", required=True, type=Path, help="Output solution JSON path")
    parser.add_argument("--name", help="Solution name to write into the JSON")
    parser.add_argument("--definition", help="Definition override; required for path variants without metadata")
    parser.add_argument("--author", default="local-profile", help="Solution author field")
    args = parser.parse_args()

    config = load_toml(PROJECT_ROOT / "config.toml")
    build_defaults = config.get("build", {})
    variant_id, variant_dir, entry = resolve_variant(args)
    definition = args.definition or entry.get("definition") or config.get("solution", {}).get("definition")
    if not definition:
        raise ValueError("Definition is required; pass --definition for path variants without metadata.")

    language = entry.get("language") or build_defaults.get("language")
    entry_point = entry.get("entry_point") or build_defaults.get("entry_point")
    if not language or not entry_point:
        raise ValueError("Variant language and entry_point must be defined in variant metadata or config.toml.")

    sources = collect_sources(variant_dir)
    seen = {source.path for source in sources}
    for include_root in build_defaults.get("dev_include_roots", []):
        include_path = (PROJECT_ROOT / include_root).resolve()
        for source_file in collect_sources(include_path):
            if source_file.path in seen:
                raise ValueError(f"Duplicate packed source path {source_file.path!r} from {include_root!r}")
            seen.add(source_file.path)
            sources.append(source_file)

    spec = BuildSpec(
        language=language,
        target_hardware=["cuda"],
        entry_point=entry_point,
        dependencies=[],
        destination_passing_style=bool(entry.get("destination_passing_style", build_defaults.get("destination_passing_style", True))),
        binding=entry.get("binding", build_defaults.get("binding")),
    )
    solution = Solution(
        name=args.name or variant_id,
        definition=definition,
        author=args.author,
        spec=spec,
        sources=sources,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(solution.model_dump_json(indent=2), encoding="utf-8")
    print(f"Packed {variant_dir} -> {args.output}")
    print(f"name={solution.name} definition={solution.definition} sources={len(solution.sources)}")


if __name__ == "__main__":
    main()
