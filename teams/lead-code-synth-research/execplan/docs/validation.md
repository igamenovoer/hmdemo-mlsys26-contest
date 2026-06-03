# Validation

## Purpose

Record authoring-time validation posture for the generated execplan.

## Checks

- The package uses the standard `execplan-shell` scaffold.
- `specs/collab/collab-overview.md` is the process-first authority.
- Topology mode is `generic-loop` with bounded repeat visits.
- Mail families are registered in `specs/comms/templates.toml` with schema and renderer paths.
- State uses SQLite contracts under `specs/state/`.
- Agent bindings reference workspace policies rather than replacing workspace contracts.
- Runtime benchmark and profiling commands are intentionally deferred to run setup.

## Stale Downstream Artifacts

No downstream runtime artifacts exist yet. No live agents, workspaces, mailboxes, gateways, or runs were created by generation.
