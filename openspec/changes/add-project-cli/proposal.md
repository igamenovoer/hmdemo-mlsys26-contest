## Why

The repo has starter scripts for packing and benchmarking, but it lacks a small control surface for managing CUDA kernel candidates and repeatable workload subsets. A tracked `project-cli` will make local optimization loops less error-prone without adopting the heavier control-plane layout from `agentic-cuda-general`.

## What Changes

- Add a `project-cli` console command for repo-local operations.
- Add tracked config files under `configs/`:
  - `configs/variants.toml` for CUDA variant inventory and template defaults.
  - `configs/workloads.toml` for workload sources and named workload sets.
- Add variant management commands for listing, showing, creating, deploying, stocking, status checking, and diffing CUDA variants.
- Add workload management commands for registering/listing/showing/removing workload sources and workload sets, plus inspecting workloads from a source.
- Keep `project-cli` scoped to management only; no `eval timing` command is part of this change.

## Capabilities

### New Capabilities

- `project-cli-variants`: Manage tracked CUDA kernel variants and synchronize them with the live `solution/cuda/` bundle.
- `project-cli-workloads`: Manage tracked workload sources and named workload sets, and inspect workload records from the local contest dataset.

### Modified Capabilities

None.

## Impact

- Adds a Python CLI entry point in `pyproject.toml`.
- Adds CLI implementation under `src/hmdemo_mlsys26_contest/`.
- Adds tracked config files under `configs/`.
- Adds tracked variant storage under `variants/`.
- Adds tests for config parsing, command behavior, and file synchronization.
- Does not replace `scripts/pack_solution.py`, `scripts/run_local.py`, `scripts/run_modal.py`, or the existing Pixi tasks.
