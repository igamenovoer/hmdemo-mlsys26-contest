"""TOML config loading and saving for project-cli."""

from __future__ import annotations

import re
import tomllib
from pathlib import Path
from typing import Any

import tomlkit

from hmdemo_mlsys26_contest.errors import ProjectCliError
from hmdemo_mlsys26_contest.models import (
    BuildMetadata,
    LiveConfig,
    VariantEntry,
    VariantManifest,
    WorkloadSet,
    WorkloadSource,
)
from hmdemo_mlsys26_contest.paths import RepoPaths

NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def validate_kebab_name(value: str, label: str) -> None:
    """Validate a CLI-facing lowercase kebab-case name."""
    if not NAME_PATTERN.fullmatch(value):
        raise ProjectCliError(f"{label} must use lowercase kebab-case, got {value!r}.")


def read_toml(path: Path) -> dict[str, Any]:
    """Read a TOML document."""
    if not path.exists():
        raise ProjectCliError(f"Missing TOML config: {path}")
    with path.open("rb") as handle:
        return tomllib.load(handle)


def _require_table(data: dict[str, Any], key: str, path: Path) -> dict[str, Any]:
    value = data.get(key)
    if not isinstance(value, dict):
        raise ProjectCliError(f"Expected [{key}] table in {path}.")
    return value


def _require_string(data: dict[str, Any], key: str, path: Path) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not value:
        raise ProjectCliError(f"Expected non-empty string {key!r} in {path}.")
    return value


def _optional_string(data: dict[str, Any], key: str) -> str | None:
    value = data.get(key)
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        raise ProjectCliError(f"Expected string {key!r}.")
    return value


def _optional_bool(data: dict[str, Any], key: str, default: bool) -> bool:
    value = data.get(key, default)
    if not isinstance(value, bool):
        raise ProjectCliError(f"Expected boolean {key!r}.")
    return value


def load_live_config(paths: RepoPaths) -> LiveConfig:
    """Load the live submission config."""
    data = read_toml(paths.config_toml)
    solution = _require_table(data, "solution", paths.config_toml)
    build = _require_table(data, "build", paths.config_toml)
    language = _require_string(build, "language", paths.config_toml)
    binding = _optional_string(build, "binding")
    if language == "cuda" and binding is None:
        binding = "tvm-ffi"
    return LiveConfig(
        name=_require_string(solution, "name", paths.config_toml),
        author=_require_string(solution, "author", paths.config_toml),
        definition=_require_string(solution, "definition", paths.config_toml),
        language=language,
        build=BuildMetadata(
            entry_point=_require_string(build, "entry_point", paths.config_toml),
            binding=binding,
            destination_passing_style=_optional_bool(build, "destination_passing_style", True),
        ),
    )


def load_variant_manifest(path: Path) -> VariantManifest:
    """Load one variant manifest."""
    data = read_toml(path)
    build = _require_table(data, "build", path)
    return VariantManifest(
        variant_id=_require_string(data, "id", path),
        language=_require_string(data, "language", path),
        definition=_require_string(data, "definition", path),
        build=BuildMetadata(
            entry_point=_require_string(build, "entry_point", path),
            binding=_optional_string(build, "binding"),
            destination_passing_style=_optional_bool(build, "destination_passing_style", True),
        ),
    )


def save_variant_manifest(path: Path, manifest: VariantManifest) -> None:
    """Write one variant manifest."""
    doc = tomlkit.document()
    doc.add("id", manifest.variant_id)
    doc.add("language", manifest.language)
    doc.add("definition", manifest.definition)
    build = tomlkit.table()
    build.add("entry_point", manifest.build.entry_point)
    if manifest.build.binding:
        build.add("binding", manifest.build.binding)
    build.add("destination_passing_style", manifest.build.destination_passing_style)
    doc.add("build", build)
    path.write_text(tomlkit.dumps(doc))


def load_variant_entries(paths: RepoPaths) -> tuple[str, dict[str, VariantEntry]]:
    """Load registered variants and default template name."""
    data = read_toml(paths.variants_toml)
    default_template = _require_string(data, "default_template", paths.variants_toml)
    variants = _require_table(data, "variants", paths.variants_toml)
    entries: dict[str, VariantEntry] = {}
    for variant_id, raw in variants.items():
        if not isinstance(raw, dict):
            raise ProjectCliError(f"Variant {variant_id!r} must be a TOML table.")
        validate_kebab_name(variant_id, "Variant ID")
        language = _require_string(raw, "language", paths.variants_toml)
        if language != "cuda":
            raise ProjectCliError(f"Only cuda variants are supported, got {language!r}.")
        path = _require_string(raw, "path", paths.variants_toml)
        if not path.startswith("cuda/"):
            raise ProjectCliError(f"Variant {variant_id!r} path must live under cuda/.")
        entries[variant_id] = VariantEntry(
            variant_id=variant_id,
            language=language,
            definition=_require_string(raw, "definition", paths.variants_toml),
            path=path,
            build=BuildMetadata(
                entry_point=_require_string(raw, "entry_point", paths.variants_toml),
                binding=_optional_string(raw, "binding"),
                destination_passing_style=_optional_bool(raw, "destination_passing_style", True),
            ),
        )
    return default_template, entries


def save_variant_entries(
    paths: RepoPaths,
    default_template: str,
    entries: dict[str, VariantEntry],
) -> None:
    """Write registered variants in deterministic order."""
    doc = tomlkit.document()
    doc.add("version", 1)
    doc.add("default_template", default_template)
    variants = tomlkit.table()
    for variant_id in sorted(entries):
        entry = entries[variant_id]
        table = tomlkit.table()
        table.add("language", entry.language)
        table.add("definition", entry.definition)
        table.add("path", entry.path)
        table.add("entry_point", entry.build.entry_point)
        if entry.build.binding:
            table.add("binding", entry.build.binding)
        table.add("destination_passing_style", entry.build.destination_passing_style)
        variants.add(variant_id, table)
    doc.add("variants", variants)
    paths.variants_toml.write_text(tomlkit.dumps(doc))


def load_workload_config(
    paths: RepoPaths,
) -> tuple[str, dict[str, WorkloadSource], dict[str, WorkloadSet]]:
    """Load workload sources and sets."""
    data = read_toml(paths.workloads_toml)
    default_source = _require_string(data, "default_source", paths.workloads_toml)
    sources_raw = _require_table(data, "sources", paths.workloads_toml)
    sets_raw = _require_table(data, "sets", paths.workloads_toml)
    sources: dict[str, WorkloadSource] = {}
    sets: dict[str, WorkloadSet] = {}

    for name, raw in sources_raw.items():
        if not isinstance(raw, dict):
            raise ProjectCliError(f"Workload source {name!r} must be a TOML table.")
        validate_kebab_name(name, "Workload source name")
        kind = _require_string(raw, "kind", paths.workloads_toml)
        if kind == "dataset-root":
            sources[name] = WorkloadSource(
                name=name,
                kind=kind,
                path=_require_string(raw, "path", paths.workloads_toml),
            )
        elif kind == "workload-dir":
            sources[name] = WorkloadSource(
                name=name,
                kind=kind,
                dataset_root=_require_string(raw, "dataset_root", paths.workloads_toml),
                workload_dir=_require_string(raw, "workload_dir", paths.workloads_toml),
            )
        else:
            raise ProjectCliError(f"Unsupported workload source kind {kind!r}.")

    for name, raw in sets_raw.items():
        if not isinstance(raw, dict):
            raise ProjectCliError(f"Workload set {name!r} must be a TOML table.")
        validate_kebab_name(name, "Workload set name")
        workloads = raw.get("workloads")
        if not isinstance(workloads, list) or not all(isinstance(item, str) for item in workloads):
            raise ProjectCliError(f"Workload set {name!r} must define a string workloads list.")
        if len(workloads) != len(set(workloads)):
            raise ProjectCliError(f"Workload set {name!r} contains duplicate workloads.")
        source = _require_string(raw, "source", paths.workloads_toml)
        if source not in sources:
            raise ProjectCliError(f"Workload set {name!r} references unknown source {source!r}.")
        sets[name] = WorkloadSet(
            name=name,
            source=source,
            definition=_require_string(raw, "definition", paths.workloads_toml),
            workloads=tuple(workloads),
        )

    if default_source not in sources:
        raise ProjectCliError(f"default_source {default_source!r} is not registered.")
    return default_source, sources, sets


def save_workload_config(
    paths: RepoPaths,
    default_source: str,
    sources: dict[str, WorkloadSource],
    sets: dict[str, WorkloadSet],
) -> None:
    """Write workload sources and sets in deterministic order."""
    doc = tomlkit.document()
    doc.add("version", 1)
    doc.add("default_source", default_source)

    sources_table = tomlkit.table()
    for name in sorted(sources):
        source = sources[name]
        table = tomlkit.table()
        table.add("kind", source.kind)
        if source.kind == "dataset-root":
            table.add("path", source.path or "")
        else:
            table.add("dataset_root", source.dataset_root or "")
            table.add("workload_dir", source.workload_dir or "")
        sources_table.add(name, table)
    doc.add("sources", sources_table)

    sets_table = tomlkit.table()
    for name in sorted(sets):
        workload_set = sets[name]
        table = tomlkit.table()
        table.add("source", workload_set.source)
        table.add("definition", workload_set.definition)
        arr = tomlkit.array()
        arr.multiline(True)
        for workload in workload_set.workloads:
            arr.add_line(workload)
        table.add("workloads", arr)
        sets_table.add(name, table)
    doc.add("sets", sets_table)
    paths.workloads_toml.write_text(tomlkit.dumps(doc))
