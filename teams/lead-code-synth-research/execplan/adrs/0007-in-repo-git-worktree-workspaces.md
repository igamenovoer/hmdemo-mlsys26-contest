# Execplan ADR 0007: In-Repo Git Worktree Workspaces

## Status

Accepted

## Context

The generated workspace contract selected an `in-repo` workspace flavor and required six isolated managed-agent workspaces, but it did not say whether `prepare-workspace` should create Git worktrees, plain untracked directories, or validate manual paths. This affects parallel Coder source edits, candidate handoff recovery, branch isolation, workspace validation, and launch readiness because the loop has two symmetric CUDA Coders working in parallel.

## Question

How should `prepare-workspace` materialize the six isolated `lcsr-*` workspaces?

## Decision

Use standard in-repo Git worktrees. `prepare-workspace` should plan or create six task-scoped workspaces under `houmao-ws/lead-code-synth-research/`, one per concrete `lcsr-*` agent. Each agent gets a private `repo/` Git worktree on branch `houmao/lead-code-synth-research/<agent-name>/main`, an agent-local `states/` directory, shared read access to sibling worktrees and states, and default launch cwd at the repo root. The task root also has `shared-kb/`, `owner-states/<run-id>/`, and `workspace.md`; the repo-level `houmao-ws/workspaces.md` index is expected.

## Consequences

- `execplan/specs/workspace/workspace.toml` now records the concrete in-repo Git worktree layout, task root, branch template, shared surfaces, and per-agent paths.
- Final support docs now summarize the concrete workspace materialization choice.
- `execplan/manifest.toml` now indexes this ADR and records the workspace materialization consistency note.
- `prepare-workspace` should route standard planning, creation, validation, and summaries through `houmao-utils-workspace-mgr`; no live workspace was created by this clarification.
