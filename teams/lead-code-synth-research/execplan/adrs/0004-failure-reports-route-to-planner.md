# Execplan ADR 0004: Failure Reports Route to Planner

## Status

Accepted

## Context

The process overview said non-GPU blockers produce `failure-report` mail to Planner, but the result-routing section also allowed failure reports to route to Synthesizer when candidate comparison was affected. That left generated communication contracts ambiguous: failure reports could fan out to Planner and Synthesizer, or Planner could remain the recovery owner while Synthesizer reads failed Coder slot status from generated state. This affects mailbox fan-out, Planner recovery ownership, Synthesizer scheduling, and state query requirements.

## Question

How should `failure-report` route after a non-GPU blocker exhausts three retries?

## Decision

`failure-report` mail goes to Planner only. Synthesizer queries generated state for failed Coder slot status before deciding whether available Coder results are sufficient for synthesis.

## Consequences

- `execplan/specs/collab/collab-overview.md` now states that failure reports route to Planner only and that Synthesizer learns failed Coder slot status through generated state queries.
- Planner remains the mail recipient and recovery owner for non-GPU blockers after three failed retries.
- Future communication, state, harness, Synthesizer tick, and Planner recovery contracts must preserve this route and query behavior.
- No downstream generated contracts, harness material, generated skills, agent bindings, docs, or manifest entries exist yet, so nothing downstream is stale.
