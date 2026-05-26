"""CUDA variant management for project-cli."""

from __future__ import annotations

import difflib
import shutil
from pathlib import Path

from hmdemo_mlsys26_contest.config_store import (
    load_live_config,
    load_variant_entries,
    load_variant_manifest,
    save_variant_entries,
    save_variant_manifest,
    validate_kebab_name,
)
from hmdemo_mlsys26_contest.errors import ProjectCliError
from hmdemo_mlsys26_contest.models import VariantEntry, VariantManifest
from hmdemo_mlsys26_contest.paths import RepoPaths, resolve_repo_paths

MANAGED_CUDA_FILES = ("kernel.cu", "binding.py")


class VariantManager:
    """High-level CUDA variant operations."""

    def __init__(self, paths: RepoPaths) -> None:
        self.paths = paths

    @classmethod
    def discover(cls) -> VariantManager:
        """Create a manager rooted at the current repository."""
        return cls(resolve_repo_paths())

    def list_variants(self) -> list[VariantEntry]:
        """List registered variants in stable order."""
        _, entries = load_variant_entries(self.paths)
        return [entries[name] for name in sorted(entries)]

    def show_variant(self, variant_id: str) -> tuple[VariantEntry, VariantManifest]:
        """Show one registered variant."""
        entry = self._require_entry(variant_id)
        manifest = self._load_manifest(entry)
        return entry, manifest

    def new_variant(
        self,
        variant_id: str,
        definition: str,
        template_name: str | None = None,
        deploy: bool = False,
    ) -> VariantEntry:
        """Create and register a new variant from a tracked template."""
        validate_kebab_name(variant_id, "Variant ID")
        default_template, entries = load_variant_entries(self.paths)
        if variant_id in entries:
            raise ProjectCliError(f"Variant {variant_id!r} already exists.")
        selected_template = template_name or default_template
        template_dir = self.paths.templates_dir / selected_template
        self._validate_bundle(template_dir, require_manifest=True)

        destination = self.paths.cuda_variants_dir / variant_id
        if destination.exists():
            raise ProjectCliError(f"Variant directory already exists: {destination}")
        shutil.copytree(template_dir, destination)

        template_manifest = load_variant_manifest(destination / "variant.toml")
        live_config = load_live_config(self.paths)
        build = live_config.build if live_config.language == "cuda" else template_manifest.build
        manifest = VariantManifest(
            variant_id=variant_id,
            language="cuda",
            definition=definition,
            build=build,
        )
        save_variant_manifest(destination / "variant.toml", manifest)

        entry = VariantEntry(
            variant_id=variant_id,
            language="cuda",
            definition=definition,
            path=f"cuda/{variant_id}",
            build=build,
        )
        entries[variant_id] = entry
        save_variant_entries(self.paths, default_template, entries)

        if deploy:
            self.deploy_variant(variant_id)
        return entry

    def deploy_variant(self, variant_id: str) -> None:
        """Deploy a stored variant into solution/cuda/."""
        entry = self._require_entry(variant_id)
        manifest = self._load_manifest(entry)
        variant_dir = self._variant_dir(entry)
        self._validate_bundle(variant_dir, require_manifest=True)
        self._validate_live_config_matches(manifest)
        self._copy_bundle(variant_dir, self.paths.solution_cuda_dir)

    def stock_variant(self, variant_id: str) -> None:
        """Copy live CUDA files back into a registered variant."""
        default_template, entries = load_variant_entries(self.paths)
        entry = self._require_entry(variant_id, entries)
        live_config = load_live_config(self.paths)
        if live_config.language != "cuda":
            raise ProjectCliError(
                "The live config.toml is not using language = 'cuda', so the CUDA bundle "
                "cannot be stocked."
            )
        self._validate_bundle(self.paths.solution_cuda_dir, require_manifest=False)
        variant_dir = self._variant_dir(entry)
        self._validate_bundle(variant_dir, require_manifest=True)
        self._copy_bundle(self.paths.solution_cuda_dir, variant_dir)

        manifest = VariantManifest(
            variant_id=variant_id,
            language="cuda",
            definition=live_config.definition,
            build=live_config.build,
        )
        save_variant_manifest(variant_dir / "variant.toml", manifest)
        entries[variant_id] = VariantEntry(
            variant_id=variant_id,
            language="cuda",
            definition=live_config.definition,
            path=entry.path,
            build=live_config.build,
        )
        save_variant_entries(self.paths, default_template, entries)

    def status(self) -> list[str]:
        """Return registered variants exactly matching the live bundle."""
        self._validate_bundle(self.paths.solution_cuda_dir, require_manifest=False)
        matches: list[str] = []
        for entry in self.list_variants():
            variant_dir = self._variant_dir(entry)
            self._validate_bundle(variant_dir, require_manifest=True)
            if self._bundle_matches(variant_dir, self.paths.solution_cuda_dir):
                matches.append(entry.variant_id)
        return matches

    def diff_variant(self, variant_id: str) -> dict[str, str]:
        """Return unified diffs from stored variant to live bundle."""
        entry = self._require_entry(variant_id)
        variant_dir = self._variant_dir(entry)
        self._validate_bundle(variant_dir, require_manifest=True)
        self._validate_bundle(self.paths.solution_cuda_dir, require_manifest=False)
        diffs: dict[str, str] = {}
        for file_name in MANAGED_CUDA_FILES:
            variant_path = variant_dir / file_name
            live_path = self.paths.solution_cuda_dir / file_name
            variant_text = variant_path.read_text().splitlines()
            live_text = live_path.read_text().splitlines()
            if variant_text == live_text:
                continue
            diff = difflib.unified_diff(
                variant_text,
                live_text,
                fromfile=f"variants/{entry.path}/{file_name}",
                tofile=f"solution/cuda/{file_name}",
                lineterm="",
            )
            diffs[file_name] = "\n".join(diff)
        return diffs

    def _require_entry(
        self,
        variant_id: str,
        entries: dict[str, VariantEntry] | None = None,
    ) -> VariantEntry:
        validate_kebab_name(variant_id, "Variant ID")
        if entries is None:
            _, entries = load_variant_entries(self.paths)
        try:
            return entries[variant_id]
        except KeyError as exc:
            raise ProjectCliError(
                f"Unknown variant {variant_id!r}. Create it with "
                f"`project-cli variant new {variant_id} --definition <definition>`."
            ) from exc

    def _variant_dir(self, entry: VariantEntry) -> Path:
        return self.paths.variants_dir / entry.path

    def _load_manifest(self, entry: VariantEntry) -> VariantManifest:
        manifest = load_variant_manifest(self._variant_dir(entry) / "variant.toml")
        if manifest.variant_id != entry.variant_id:
            raise ProjectCliError(
                f"Variant manifest ID {manifest.variant_id!r} does not match "
                f"catalog ID {entry.variant_id!r}."
            )
        return manifest

    def _validate_bundle(self, directory: Path, require_manifest: bool) -> None:
        if not directory.exists():
            raise ProjectCliError(f"Missing CUDA bundle directory: {directory}")
        for file_name in MANAGED_CUDA_FILES:
            if not (directory / file_name).is_file():
                raise ProjectCliError(f"CUDA bundle is missing {directory / file_name}")
        if require_manifest and not (directory / "variant.toml").is_file():
            raise ProjectCliError(f"Variant bundle is missing {directory / 'variant.toml'}")

    def _validate_live_config_matches(self, manifest: VariantManifest) -> None:
        live = load_live_config(self.paths)
        mismatches: list[str] = []
        if live.language != manifest.language:
            mismatches.append(
                f"build.language: live={live.language!r} expected={manifest.language!r}"
            )
        if live.definition != manifest.definition:
            mismatches.append(
                f"solution.definition: live={live.definition!r} expected={manifest.definition!r}"
            )
        if live.build.entry_point != manifest.build.entry_point:
            mismatches.append(
                f"build.entry_point: live={live.build.entry_point!r} "
                f"expected={manifest.build.entry_point!r}"
            )
        if live.build.binding != manifest.build.binding:
            mismatches.append(
                f"build.binding: live={live.build.binding!r} expected={manifest.build.binding!r}"
            )
        if live.build.destination_passing_style != manifest.build.destination_passing_style:
            mismatches.append(
                "build.destination_passing_style: "
                f"live={live.build.destination_passing_style!r} "
                f"expected={manifest.build.destination_passing_style!r}"
            )
        if mismatches:
            detail = "\n".join(f"- {item}" for item in mismatches)
            raise ProjectCliError(
                "The live config.toml does not match the selected variant:\n" + detail
            )

    def _copy_bundle(self, source: Path, destination: Path) -> None:
        destination.mkdir(parents=True, exist_ok=True)
        for file_name in MANAGED_CUDA_FILES:
            shutil.copy2(source / file_name, destination / file_name)

    def _bundle_matches(self, variant_dir: Path, live_dir: Path) -> bool:
        return all(
            (variant_dir / file_name).read_bytes() == (live_dir / file_name).read_bytes()
            for file_name in MANAGED_CUDA_FILES
        )
