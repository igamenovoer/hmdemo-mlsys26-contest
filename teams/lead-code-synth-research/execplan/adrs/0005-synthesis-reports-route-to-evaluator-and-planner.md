# Execplan ADR 0005: Synthesis Reports Route to Evaluator and Planner

## Status

Accepted

## Context

The process overview said Synthesizer sends a promotion candidate to Evaluator and also said synthesis reports route to Planner as next-cycle context. It did not decide whether Planner should receive `synthesis-report` mail directly, query generated state, or sit in front of Evaluator. This affects mailbox fan-out, Planner context freshness, Evaluator promotion ownership, and the invariant that Planner cannot write current-best until Evaluator accepts promotion evidence.

## Question

Should `synthesis-report` mail go only to Evaluator, or also directly to Planner for next-cycle context?

## Decision

`synthesis-report` mail goes to Evaluator and Planner. Evaluator treats it as a promotion review input. Planner treats it as context only and cannot update current-best from synthesis evidence alone.

## Consequences

- `execplan/specs/collab/collab-overview.md` now states that Synthesizer sends `synthesis-report` to Evaluator and Planner, and that Planner's copy is next-cycle context only.
- Evaluator remains the only role that can produce accepted promotion evidence, and Planner still writes current-best only from accepted Evaluator evidence.
- Future communication, state, harness, Planner event, Evaluator event, and notifier contracts must preserve this route and authority split.
- No downstream generated contracts, harness material, generated skills, agent bindings, docs, or manifest entries exist yet, so nothing downstream is stale.
