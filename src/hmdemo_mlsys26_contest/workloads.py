"""Workload source and set management for project-cli."""

from __future__ import annotations

import json
from pathlib import Path

from hmdemo_mlsys26_contest.config_store import (
    load_live_config,
    load_workload_config,
    save_workload_config,
    validate_kebab_name,
)
from hmdemo_mlsys26_contest.errors import ProjectCliError
from hmdemo_mlsys26_contest.models import WorkloadRecord, WorkloadSet, WorkloadSource
from hmdemo_mlsys26_contest.paths import RepoPaths, resolve_repo_paths


class WorkloadManager:
    """High-level workload operations."""

    def __init__(self, paths: RepoPaths) -> None:
        self.paths = paths

    @classmethod
    def discover(cls) -> WorkloadManager:
        """Create a manager rooted at the current repository."""
        return cls(resolve_repo_paths())

    def list_sources(self) -> list[WorkloadSource]:
        """List workload sources."""
        _, sources, _ = load_workload_config(self.paths)
        return [sources[name] for name in sorted(sources)]

    def show_source(self, name: str) -> WorkloadSource:
        """Show one workload source."""
        _, sources, _ = load_workload_config(self.paths)
        return self._require_source(name, sources)

    def register_source(
        self,
        name: str,
        kind: str,
        path: str | None,
        dataset_root: str | None,
        workload_dir: str | None,
    ) -> WorkloadSource:
        """Register one workload source."""
        validate_kebab_name(name, "Workload source name")
        default_source, sources, sets = load_workload_config(self.paths)
        if name in sources:
            raise ProjectCliError(f"Workload source {name!r} already exists.")
        if kind == "dataset-root":
            if not path:
                raise ProjectCliError("--path is required for dataset-root sources.")
            source = WorkloadSource(name=name, kind=kind, path=path)
        elif kind == "workload-dir":
            if not dataset_root or not workload_dir:
                raise ProjectCliError(
                    "--dataset-root and --workload-dir are required for workload-dir sources."
                )
            source = WorkloadSource(
                name=name,
                kind=kind,
                dataset_root=dataset_root,
                workload_dir=workload_dir,
            )
        else:
            raise ProjectCliError(f"Unsupported workload source kind {kind!r}.")
        sources[name] = source
        save_workload_config(self.paths, default_source, sources, sets)
        return source

    def remove_source(self, name: str) -> None:
        """Remove one workload source."""
        default_source, sources, sets = load_workload_config(self.paths)
        self._require_source(name, sources)
        if name == default_source:
            raise ProjectCliError(f"Cannot remove default workload source {name!r}.")
        users = [set_name for set_name, workload_set in sets.items() if workload_set.source == name]
        if users:
            raise ProjectCliError(
                f"Cannot remove workload source {name!r}; used by sets: {', '.join(users)}."
            )
        del sources[name]
        save_workload_config(self.paths, default_source, sources, sets)

    def list_workloads(
        self,
        source_name: str | None,
        definition: str | None,
        uuid_prefix: str | None,
        limit: int | None,
    ) -> list[WorkloadRecord]:
        """List workload records."""
        selected_definition = definition or load_live_config(self.paths).definition
        records = self._load_records(source_name, selected_definition)
        if uuid_prefix:
            records = [record for record in records if record.uuid.startswith(uuid_prefix)]
        if limit is not None:
            records = records[:limit]
        return records

    def show_workload(
        self,
        selector: str,
        source_name: str | None,
        definition: str | None,
    ) -> WorkloadRecord:
        """Show one workload by exact UUID or unique prefix."""
        selected_definition = definition or load_live_config(self.paths).definition
        return self._resolve_record(selector, source_name, selected_definition)

    def list_sets(self) -> list[WorkloadSet]:
        """List workload sets."""
        _, _, sets = load_workload_config(self.paths)
        return [sets[name] for name in sorted(sets)]

    def show_set(self, name: str) -> WorkloadSet:
        """Show one workload set."""
        _, _, sets = load_workload_config(self.paths)
        return self._require_set(name, sets)

    def register_set(
        self,
        name: str,
        source_name: str,
        definition: str,
        workload_selectors: tuple[str, ...],
        from_file: Path | None,
    ) -> WorkloadSet:
        """Register one workload set, resolving selectors to exact UUIDs."""
        validate_kebab_name(name, "Workload set name")
        default_source, sources, sets = load_workload_config(self.paths)
        self._require_source(source_name, sources)
        if name in sets:
            raise ProjectCliError(f"Workload set {name!r} already exists.")
        selectors = list(workload_selectors)
        if from_file is not None:
            selectors.extend(
                line.strip()
                for line in from_file.read_text().splitlines()
                if line.strip() and not line.strip().startswith("#")
            )
        if not selectors:
            raise ProjectCliError("At least one --workload or --from-file selector is required.")
        exact: list[str] = []
        for selector in selectors:
            record = self._resolve_record(selector, source_name, definition)
            if record.uuid in exact:
                raise ProjectCliError(f"Duplicate workload selector resolved to {record.uuid}.")
            exact.append(record.uuid)
        workload_set = WorkloadSet(
            name=name,
            source=source_name,
            definition=definition,
            workloads=tuple(exact),
        )
        sets[name] = workload_set
        save_workload_config(self.paths, default_source, sources, sets)
        return workload_set

    def remove_set(self, name: str) -> None:
        """Remove one workload set."""
        default_source, sources, sets = load_workload_config(self.paths)
        self._require_set(name, sets)
        del sets[name]
        save_workload_config(self.paths, default_source, sources, sets)

    def _require_source(
        self,
        name: str,
        sources: dict[str, WorkloadSource],
    ) -> WorkloadSource:
        try:
            return sources[name]
        except KeyError as exc:
            raise ProjectCliError(f"Unknown workload source {name!r}.") from exc

    def _require_set(self, name: str, sets: dict[str, WorkloadSet]) -> WorkloadSet:
        try:
            return sets[name]
        except KeyError as exc:
            raise ProjectCliError(f"Unknown workload set {name!r}.") from exc

    def _selected_source(self, source_name: str | None) -> WorkloadSource:
        default_source, sources, _ = load_workload_config(self.paths)
        return self._require_source(source_name or default_source, sources)

    def _resolve_source_paths(self, source: WorkloadSource) -> tuple[Path, Path]:
        if source.kind == "dataset-root":
            dataset_root = self.paths.repo_path(source.path or "")
            workload_root = dataset_root / "workloads"
        else:
            dataset_root = self.paths.repo_path(source.dataset_root or "")
            workload_root = self.paths.repo_path(source.workload_dir or "")
        if not dataset_root.exists():
            raise ProjectCliError(f"Dataset root does not exist: {dataset_root}")
        if not workload_root.exists():
            raise ProjectCliError(f"Workload directory does not exist: {workload_root}")
        return dataset_root, workload_root

    def _workload_jsonl(self, source_name: str | None, definition: str) -> Path:
        source = self._selected_source(source_name)
        _, workload_root = self._resolve_source_paths(source)
        matches = sorted(workload_root.rglob(f"{definition}.jsonl"))
        if not matches:
            raise ProjectCliError(
                f"No workload JSONL found for definition {definition!r} in {workload_root}."
            )
        if len(matches) > 1:
            rendered = ", ".join(str(path) for path in matches)
            raise ProjectCliError(
                f"Multiple workload JSONL files found for definition {definition!r}: {rendered}"
            )
        return matches[0]

    def _load_records(self, source_name: str | None, definition: str) -> list[WorkloadRecord]:
        path = self._workload_jsonl(source_name, definition)
        records: list[WorkloadRecord] = []
        for line_number, line in enumerate(path.read_text().splitlines(), start=1):
            if not line.strip():
                continue
            try:
                data = json.loads(line)
                workload = data["workload"]
                uuid = workload["uuid"]
            except (json.JSONDecodeError, KeyError, TypeError) as exc:
                raise ProjectCliError(f"Invalid workload record at {path}:{line_number}.") from exc
            if not isinstance(uuid, str) or not uuid:
                raise ProjectCliError(f"Invalid workload UUID at {path}:{line_number}.")
            records.append(WorkloadRecord(uuid=uuid, data=data))
        return records

    def _resolve_record(
        self,
        selector: str,
        source_name: str | None,
        definition: str,
    ) -> WorkloadRecord:
        records = self._load_records(source_name, definition)
        matches = [record for record in records if record.uuid == selector]
        if not matches:
            matches = [record for record in records if record.uuid.startswith(selector)]
        if not matches:
            raise ProjectCliError(f"No workload matches selector {selector!r}.")
        if len(matches) > 1:
            uuids = ", ".join(record.uuid for record in matches)
            raise ProjectCliError(f"Workload selector {selector!r} is ambiguous: {uuids}")
        return matches[0]
