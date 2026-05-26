## 1. CLI Packaging

- [ ] 1.1 Add `project-cli` console script entry point in `pyproject.toml`.
- [ ] 1.2 Add the CLI module structure under `src/hmdemo_mlsys26_contest/`.
- [ ] 1.3 Add Click dependency if it is not already available in the Pixi/Python environment.

## 2. Shared Config Files

- [ ] 2.1 Add `configs/variants.toml` with version, default template, and initial empty variant registry.
- [ ] 2.2 Add `configs/workloads.toml` with version, default source, `contest-local` source, and initial workload sets.
- [ ] 2.3 Implement TOML loading and deterministic saving helpers for both config files.
- [ ] 2.4 Implement validation for variant IDs, source definitions, workload set definitions, and duplicate entries.

## 3. Variant Management

- [ ] 3.1 Add `variants/templates/cuda-default/` with `variant.toml`, `kernel.cu`, and `binding.py`.
- [ ] 3.2 Implement `project-cli variant list` and `project-cli variant show`.
- [ ] 3.3 Implement `project-cli variant new` with `--definition`, `--template`, and `--deploy`.
- [ ] 3.4 Implement `project-cli variant deploy` with live `config.toml` compatibility checks.
- [ ] 3.5 Implement `project-cli variant stock` to copy live CUDA files back into a registered variant.
- [ ] 3.6 Implement `project-cli variant status` exact-match reporting.
- [ ] 3.7 Implement `project-cli variant diff` with unified diffs for managed CUDA files.

## 4. Workload Management

- [ ] 4.1 Implement `project-cli workload source list`, `show`, `register`, and `remove`.
- [ ] 4.2 Implement workload source resolution for `dataset-root` and `workload-dir` sources.
- [ ] 4.3 Implement workload JSONL loading for a selected source and exact definition.
- [ ] 4.4 Implement `project-cli workload list` with source, definition, UUID prefix, and limit filters.
- [ ] 4.5 Implement `project-cli workload show` with exact UUID and unique-prefix matching.
- [ ] 4.6 Implement `project-cli workload set list`, `show`, `register`, and `remove`.
- [ ] 4.7 Ensure workload set registration stores exact UUIDs after resolving prefixes.

## 5. Tests

- [ ] 5.1 Add unit tests for config loading, saving, and validation failures.
- [ ] 5.2 Add CLI tests for variant list/show/new/deploy/stock/status/diff.
- [ ] 5.3 Add CLI tests for workload source and workload set commands.
- [ ] 5.4 Add tests for ambiguous, unknown, and duplicate workload selectors.
- [ ] 5.5 Add tests proving no `project-cli eval timing` command exists.

## 6. Documentation and Verification

- [ ] 6.1 Document `project-cli` usage in repo docs or `AGENTS.md`.
- [ ] 6.2 Run `pixi run test`.
- [ ] 6.3 Run `pixi run lint`.
- [ ] 6.4 Run `pixi run typecheck`.
- [ ] 6.5 Smoke-test `project-cli --help`, `project-cli variant --help`, and `project-cli workload --help`.
