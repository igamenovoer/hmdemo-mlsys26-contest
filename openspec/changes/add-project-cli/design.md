## Context

This repository is a Pixi-managed FlashInfer MLSys 2026 contest starter kit. It currently has `config.toml`, `solution/cuda/`, `solution/triton/`, and helper scripts for packing and benchmarking, but it does not have a stable way to keep multiple CUDA implementation candidates or reusable workload subsets organized.

`agentic-cuda-general` provides a richer `mlsys-cli` with `.mlsys-config/`, schema-backed catalogs, variant management, workload management, and timing. This change borrows the useful command shape while simplifying storage for this repo: tracked TOML files live directly under `configs/`, and timing remains outside the CLI.

## Goals / Non-Goals

**Goals:**

- Provide a `project-cli` console command for variant and workload management.
- Store shared configuration in tracked files at `configs/variants.toml` and `configs/workloads.toml`.
- Treat `solution/cuda/` as the live CUDA working bundle and `variants/cuda/<variant-id>/` as stored candidate inventory.
- Support creating variants from templates, deploying variants to the live bundle, stocking live edits back into variants, comparing status, and showing diffs.
- Support workload source registration, workload listing/showing, and named workload set registration using the local contest dataset checkout.
- Keep default commands deterministic and script-friendly for agent workflows.

**Non-Goals:**

- Do not add `project-cli eval timing`.
- Do not replace `scripts/pack_solution.py`, `scripts/run_local.py`, `scripts/run_modal.py`, or existing Pixi tasks.
- Do not manage Triton variants in the first version.
- Do not manage arbitrary extra CUDA dependency trees, vendored headers, or generated build artifacts.
- Do not introduce a hidden local override directory or untracked control-plane state.

## Decisions

### Use Click for the CLI

Use Click because the reference CLI uses it, the command tree is nested, and command behavior should be easy to test with `CliRunner`. Alternatives considered: `argparse` is dependency-free but more verbose for nested commands; Typer is ergonomic but would introduce another dependency.

### Expose `project-cli` as the console script

Add a `project-cli = "hmdemo_mlsys26_contest.cli:main"` entry point. This keeps the command name generic and local to the repo while avoiding confusion with the reference `mlsys-cli`.

### Keep configuration in two tracked TOML files

Use:

```text
configs/
├── variants.toml
└── workloads.toml
```

`configs/variants.toml` owns variant registry metadata and the default template name. `configs/workloads.toml` owns workload sources, default source, and workload sets. This avoids the heavier `.mlsys-config/` layout and makes review diffs straightforward.

### Manage a minimal CUDA bundle

The initial managed CUDA bundle is:

```text
solution/cuda/kernel.cu
solution/cuda/binding.py
```

Each stored variant contains:

```text
variants/cuda/<variant-id>/
├── variant.toml
├── kernel.cu
└── binding.py
```

The reference project also manages `binding.cpp` and optional `kernel_parts/`, but this starter kit only has `kernel.cu` and `binding.py` today. The CLI can be extended later if the repo adopts a larger CUDA bundle shape.

### Validate before mutating files

Commands that mutate variants or configs must load and validate relevant TOML first, then perform filesystem changes. Variant IDs must be lowercase kebab-case. Workload set registration must resolve UUID prefixes to exact unique UUIDs before writing them to `configs/workloads.toml`.

### Keep `config.toml` authoritative for the live submission

`project-cli variant deploy` must not silently rewrite `config.toml`. If a stored variant's definition, language, entry point, binding, or destination-passing metadata conflicts with the live config, the command should fail with a clear mismatch report. `stock` refreshes variant metadata from the live config.

### No timing command in this change

Timing has more complexity than inventory management: GPU selection, runner mode, tolerance overrides, temporary TraceSet generation, and benchmark reporting. This change intentionally leaves timing to existing scripts and Pixi tasks.

## Risks / Trade-offs

- Config drift between `config.toml` and a stored variant could block deploy. Mitigation: print all mismatched fields and document that `stock` refreshes metadata from the live config.
- TOML parsing without JSON Schema is lighter but less formally constrained. Mitigation: implement explicit validation in Python and cover malformed configs in tests.
- Managing only two CUDA files may be too small for future optimized kernels. Mitigation: keep the bundle list centralized so future changes can add `binding.cpp` or `kernel_parts/`.
- Workload inspection depends on the local dataset path existing. Mitigation: error clearly when the registered source path or expected workload JSONL is missing.
- No eval timing means users need multiple commands for a full optimization loop. Mitigation: document existing `pixi run bench` and `pixi run modal-bench` as evaluation paths.

## Migration Plan

1. Add the `project-cli` console script and implementation.
2. Add initial `configs/variants.toml` and `configs/workloads.toml`.
3. Add `variants/templates/cuda-default/` matching the current CUDA starter files.
4. Add unit tests for config loading, variant commands, workload commands, and file synchronization.
5. Document the command surface in `AGENTS.md` or `docs/`.

Rollback is straightforward: remove the console script, `configs/`, and `variants/` additions. Existing packing and benchmark scripts continue to work independently.

## Open Questions

- Should the first default variant be stocked from the current `solution/cuda/` immediately, or should the repo only ship the `cuda-default` template?
- Should `project-cli workload set register` support `--from-file` in the first version, or only repeatable `--workload` flags?
