# ADR 0002: Promotion Requires Official Timing

## Status

Accepted, refined by ADR 0011, ADR 0012, ADR 0013, ADR 0014, and ADR 0015

## Context

The first Fused MoE loop needs a clear rule for when a candidate can replace the current best solution. Coders may need fast local checks during exploration, but promotion affects loop state, synthesis decisions, Planner context, and terminal acceptance.

## Question

Which benchmark/evaluation path should allow a candidate to become the new best Fused MoE candidate?

## Decision

Coder exploration may use local checks, but promotion to the new best candidate requires the project `official-timing` path.

## Consequences

- Future execplan evaluation contracts should distinguish exploratory checks from promotion checks.
- Coder result mail may report local correctness and timing evidence, but the Evaluator owns promotion validation after `official-timing`.
- ADR 0011 assigns durable current-best state writes to Planner.
- The loop state should record whether a candidate is exploratory, submitted for promotion, promoted, or rejected.
- Terminal success, resource posture, runtime posture, compute posture, and retry policy were later clarified by ADR 0003 and ADR 0011 through ADR 0015.
