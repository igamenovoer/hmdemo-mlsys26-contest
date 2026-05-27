# Agent Instructions

## Project

This repository is a Pixi-managed Python starter kit for the MLSys 2026 FlashInfer AI Kernel Generation Contest. It contains helper scripts for packing and benchmarking a solution plus Triton/CUDA template implementations under `solution/`.

## OpenSpec

Use OpenSpec for non-trivial feature or workflow changes:

- Propose changes with the OpenSpec skills/commands before implementation when behavior, workflow, or project conventions change.
- Keep active change work under `openspec/changes/`.
- Keep accepted specifications under `openspec/specs/`.
- Archive completed changes with OpenSpec so specs stay current.

The repo has OpenSpec skills installed for both Codex and Claude Code:

- Codex: `.codex/skills/openspec-*`
- Claude Code: `.claude/skills/openspec-*`

Useful CLI checks:

```bash
openspec list
openspec list --specs
openspec validate <change-or-spec>
```

## Development

Use Pixi for project commands:

```bash
pixi run test
pixi run lint
pixi run typecheck
pixi run pack
pixi run -e cu130 nvcc --version
pixi run project-cli variant list
pixi run project-cli workload source list
```

`pixi run bench` requires a CUDA-capable local environment and `FIB_DATASET_PATH`.
`pixi run modal-bench` requires Modal setup.

Use `pixi run -e cu130 ...` for CUDA 13.0 / Blackwell `sm_100a` work. That environment sets `CUDA_HOME` to the PyPI `cuda-toolkit` CUDA 13 layout, adds its `bin` directory to `PATH`, and exports `TORCH_CUDA_ARCH_LIST=10.0a` plus `TVM_FFI_CUDA_ARCH_LIST=10.0a`.

Use `project-cli` for repo-local management tasks:

```bash
pixi run project-cli variant list
pixi run project-cli variant new moe-trial --definition <exact-definition>
pixi run project-cli variant deploy moe-trial
pixi run project-cli variant stock moe-trial
pixi run project-cli variant status
pixi run project-cli variant diff moe-trial
pixi run project-cli workload source list
pixi run project-cli workload list --source contest-local --definition <exact-definition> --limit 5
pixi run project-cli workload set list
```

`project-cli` intentionally has no `eval timing` command; use `pixi run bench`, `pixi run modal-bench`, or the underlying scripts for evaluation.

## Layout

- `solution/triton/`: Triton implementation templates.
- `solution/cuda/`: CUDA TVM-FFI template. The configured CUDA entry point is `kernel.cu::kernel`; `binding.py` is only a Python helper placeholder.
- `scripts/`: pack, local benchmark, and Modal benchmark helpers.
- `src/hmdemo_mlsys26_contest/`: importable Python package scaffold.
- `tests/unit/`: fast unit tests.
- `tests/integration/`: integration tests.
- `tests/manual/`: manually run checks.
- `docs/`: project documentation.
- `context/`: working context and design notes.
- `extern/tracked/`: tracked external dependencies or submodules.
- `extern/orphan/`: local-only external checkouts; ignored by Git.
- `tmp/`: disposable local files; ignored by Git.

## Guardrails

- Do not commit generated `solution.json`, `.pixi/`, `tmp/`, or files under `extern/orphan/`.
- Prefer small, focused edits that preserve the starter-kit shape expected by the contest evaluator.
- Keep GPU or dataset-dependent checks out of the default unit test path.
- Preserve Python 3.12 compatibility.
