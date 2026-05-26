"""Repository path discovery for project-cli."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from hmdemo_mlsys26_contest.errors import ProjectCliError


@dataclass(frozen=True)
class RepoPaths:
    """Resolved repository paths used by project-cli."""

    root: Path
    config_toml: Path
    configs_dir: Path
    variants_toml: Path
    workloads_toml: Path
    variants_dir: Path
    templates_dir: Path
    cuda_variants_dir: Path
    solution_cuda_dir: Path

    def repo_path(self, value: str | Path) -> Path:
        """Resolve a path relative to the repository root."""
        path = Path(value)
        if path.is_absolute():
            return path
        return self.root / path


def discover_repo_root(start: Path | None = None) -> Path:
    """Find the repository root from a working directory."""
    current = (start or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        if (candidate / "pyproject.toml").exists() and (candidate / "config.toml").exists():
            return candidate
    raise ProjectCliError(
        "Could not find repository root containing pyproject.toml and config.toml."
    )


def resolve_repo_paths(start: Path | None = None) -> RepoPaths:
    """Resolve all project-cli paths."""
    root = discover_repo_root(start)
    configs_dir = root / "configs"
    variants_dir = root / "variants"
    return RepoPaths(
        root=root,
        config_toml=root / "config.toml",
        configs_dir=configs_dir,
        variants_toml=configs_dir / "variants.toml",
        workloads_toml=configs_dir / "workloads.toml",
        variants_dir=variants_dir,
        templates_dir=variants_dir / "templates",
        cuda_variants_dir=variants_dir / "cuda",
        solution_cuda_dir=root / "solution" / "cuda",
    )
