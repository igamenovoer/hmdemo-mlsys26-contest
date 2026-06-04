# Execplan ADR 0001: Candidate Handoffs Use project-cli Variant Refs

## Status

Accepted

## Context

The process overview required Coder and Synthesizer candidate handoffs to carry candidate evidence, workspace refs, changed files, and evidence refs, but it did not decide whether downstream agents should receive `project-cli` variant refs, patches, git branches, or run-artifact patch bundles. This affects communication contracts, state records, Evaluator `official-timing` inputs, and recovery because the six managed agents use isolated workspaces.

## Question

Which handoff artifact should Coder and Synthesizer candidates use across isolated workspaces?

## Decision

Coder and Synthesizer handoffs require a `project-cli` variant id or variant directory ref, plus workspace path and evidence refs.

## Consequences

- `execplan/specs/collab/collab-overview.md` now states that Coder results, synthesis reports, candidate records, and evaluation inputs carry a `project-cli` variant id or variant directory ref, workspace path, and evidence refs.
- No downstream generated artifacts exist yet, so no existing contracts, harness material, generated skills, agent bindings, docs, or manifest entries are stale.
- Future communication, state, workspace, harness, and evaluation contracts must preserve this handoff shape.
