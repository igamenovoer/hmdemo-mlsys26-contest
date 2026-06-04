# Execplan ADR 0002: Coder Results Route to Synthesizer

## Status

Accepted

## Context

The process overview said Coder results route to Synthesizer, but also allowed Planner to receive state refs or summaries when needed for cycle ownership. That left generated communication contracts ambiguous: `coder-result` could become duplicate mail to Planner and Synthesizer, or a single routed handoff with Planner visibility through generated state. The choice affects mailbox fan-out, reply expectations, Synthesizer ownership, Planner tick behavior, and state query requirements.

## Question

Should `coder-result` mail go only to Synthesizer, or also directly to Planner?

## Decision

Routine `coder-result` mail goes to Synthesizer only. Coder result payloads are recorded in generated state or run artifacts so Planner can query them for cycle ownership, recovery, and future planning.

## Consequences

- `execplan/specs/collab/collab-overview.md` now states that `coder-result` has Synthesizer as its normal recipient and does not duplicate routine result mail to Planner.
- Planner visibility depends on generated state or run-artifact query surfaces rather than direct Coder result mail.
- No downstream generated contracts, harness material, generated skills, agent bindings, docs, or manifest entries exist yet, so nothing downstream is stale.
- Future communication, state, harness, and Planner tick contracts must preserve Synthesizer as the normal `coder-result` receiver.
