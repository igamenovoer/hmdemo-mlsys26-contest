## 1. CLI Packaging

- [x] 1.1 Add `project-cli` console script entry point in `pyproject.toml`.
- [x] 1.2 Add the CLI module structure under `src/hmdemo_mlsys26_contest/`.
- [x] 1.3 Add Click dependency if it is not already available in the Pixi/Python environment.

## 2. Shared Config Files

- [x] 2.1 Add `configs/variants.toml` with version, default template, and initial empty variant registry.
- [x] 2.2 Add `configs/workloads.toml` with version, default source, `contest-local` source, and initial workload sets.
- [x] 2.3 Implement TOML loading and deterministic saving helpers for both config files.
- [x] 2.4 Implement validation for variant IDs, source definitions, workload set definitions, and duplicate entries.

## 3. Variant Management

- [x] 3.1 Add `variants/templates/cuda-default/` with `variant.toml`, `kernel.cu`, and `binding.py`.
- [x] 3.2 Implement `project-cli variant list` and `project-cli variant show`.
- [x] 3.3 Implement `project-cli variant new` with `--definition`, `--template`, and `--deploy`.
- [x] 3.4 Implement `project-cli variant deploy` with live `config.toml` compatibility checks.
- [x] 3.5 Implement `project-cli variant stock` to copy live CUDA files back into a registered variant.
- [x] 3.6 Implement `project-cli variant status` exact-match reporting.
- [x] 3.7 Implement `project-cli variant diff` with unified diffs for managed CUDA files.

## 4. Workload Management

- [x] 4.1 Implement `project-cli workload source list`, `show`, `register`, and `remove`.
- [x] 4.2 Implement workload source resolution for `dataset-root` and `workload-dir` sources.
- [x] 4.3 Implement workload JSONL loading for a selected source and exact definition.
- [x] 4.4 Implement `project-cli workload list` with source, definition, UUID prefix, and limit filters.
- [x] 4.5 Implement `project-cli workload show` with exact UUID and unique-prefix matching.
- [x] 4.6 Implement `project-cli workload set list`, `show`, `register`, and `remove`.
- [x] 4.7 Ensure workload set registration stores exact UUIDs after resolving prefixes.

## 5. Tests

- [x] 5.1 Add unit tests for config loading, saving, and validation failures.
- [x] 5.2 Add CLI tests for variant list/show/new/deploy/stock/status/diff.
- [x] 5.3 Add CLI tests for workload source and workload set commands.
- [x] 5.4 Add tests for ambiguous, unknown, and duplicate workload selectors.
- [x] 5.5 Add tests proving no `project-cli eval timing` command exists.

## 6. Documentation and Verification

- [x] 6.1 Document `project-cli` usage in repo docs or `AGENTS.md`.
- [x] 6.2 Run `pixi run test`.
- [x] 6.3 Run `pixi run lint`.
- [x] 6.4 Run `pixi run typecheck`.
- [x] 6.5 Smoke-test `project-cli --help`, `project-cli variant --help`, and `project-cli workload --help`.
