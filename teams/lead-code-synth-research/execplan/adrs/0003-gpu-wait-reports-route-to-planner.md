# Execplan ADR 0003: GPU Wait Reports Route to Planner

## Status

Accepted

## Context

The process overview allowed Synthesizer to proceed when one Coder assignment is waiting for GPU, but it did not define whether Synthesizer learns that status through direct `gpu-wait-report` mail, Planner forwarding, or generated state. This affects mailbox fan-out, Synthesizer scheduling, Planner ownership of blocked assignments, and recovery from no-spare-GPU events.

## Question

How should Synthesizer learn that a Coder slot is waiting for GPU, so it can decide whether to proceed with available results?

## Decision

`gpu-wait-report` mail goes to Planner only. Synthesizer queries generated state for Coder slot status before deciding whether available Coder results are sufficient for synthesis.

## Consequences

- `execplan/specs/collab/collab-overview.md` now states that GPU wait mail routes to Planner only and that Synthesizer learns waiting-for-GPU status through generated state queries.
- Planner remains the mail recipient and ownership point for GPU-capacity blocked assignments.
- Future communication, state, harness, Synthesizer tick, and Planner recovery contracts must preserve this route and query behavior.
- No downstream generated contracts, harness material, generated skills, agent bindings, docs, or manifest entries exist yet, so nothing downstream is stale.
