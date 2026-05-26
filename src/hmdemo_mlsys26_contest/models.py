"""Data models for project-cli."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class BuildMetadata:
    """Deploy-relevant build metadata."""

    entry_point: str
    binding: str | None
    destination_passing_style: bool


@dataclass(frozen=True)
class LiveConfig:
    """Live submission config from config.toml."""

    name: str
    author: str
    definition: str
    language: str
    build: BuildMetadata


@dataclass(frozen=True)
class VariantEntry:
    """Registered variant entry from configs/variants.toml."""

    variant_id: str
    language: str
    definition: str
    path: str
    build: BuildMetadata


@dataclass(frozen=True)
class VariantManifest:
    """Variant-local metadata from variant.toml."""

    variant_id: str
    language: str
    definition: str
    build: BuildMetadata


@dataclass(frozen=True)
class WorkloadSource:
    """Named workload source."""

    name: str
    kind: str
    path: str | None = None
    dataset_root: str | None = None
    workload_dir: str | None = None


@dataclass(frozen=True)
class WorkloadSet:
    """Named workload set."""

    name: str
    source: str
    definition: str
    workloads: tuple[str, ...]


@dataclass(frozen=True)
class WorkloadRecord:
    """One workload JSONL record."""

    uuid: str
    data: dict[str, object]
