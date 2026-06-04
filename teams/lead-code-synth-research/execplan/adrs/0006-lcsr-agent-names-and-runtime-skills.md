# Execplan ADR 0006: lcsr Agent Names and Runtime Skills

## Status

Accepted

## Context

The generated agent bindings originally used generic concrete agent ids such as `planner`, `cuda-coder-1`, and `evaluator`. The operator requested loop-specific names so live agents are visibly tied to `lead-code-synth-research`, and also requested assigning all project runtime skills from `skillset/runtime/*` to the loop agents.

## Question

How should concrete loop agents be named and which project runtime skills should be assigned to them?

## Decision

Concrete Houmao-facing agent ids, profile dirs, workspace agent names, and notifier prompt files use the `lcsr-*` prefix. All six managed agents are assigned every skill directory under `skillset/runtime/*`: `krnopt-cuda-coding`, `krnopt-cuda-domain-optimization`, `krnopt-cuda-generic-optimization`, `krnopt-cuda-profiling`, `krnopt-cuda-structural-optimization`, `krnopt-hw-aware-optimization`, `krnopt-low-precision-kernel-formats`, `project-op-variant-comparison`, `project-op-variant-profiling`, and `project-op-variant-validation`.

## Consequences

- `execplan/agents/bindings.toml` maps stable participant ids to concrete `lcsr-*` agent ids and declares `project_runtime_skills` for each managed agent.
- `execplan/agents/profiles/*/config.toml` files use `lcsr-*` concrete agent ids and include the project runtime skill list.
- `execplan/specs/workspace/workspace.toml` now expects `lcsr-*` workspace agent names.
- Stable participant ids, role ids, mail schema ids, and process topology remain unchanged.
- Downstream final docs are stale until `execplan-finalize` runs; no live Houmao profiles, workspaces, or agents were changed by this decision.
