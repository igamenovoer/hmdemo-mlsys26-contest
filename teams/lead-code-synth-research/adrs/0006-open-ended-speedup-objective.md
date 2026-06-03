# ADR 0006: Open-Ended Fused MoE Speedup Objective

## Status

Accepted

## Context

The intention source named Fused MoE as the first optimization target and defined normal promotion to `current-best`, but it did not define the terminal objective posture. This decision affects objective contracts, terminal conditions, operator controls, run state, and validation semantics.

## Question

What terminal objective should this Fused MoE loop optimize toward?

## Decision

The loop should maximize Fused MoE speedup in an open-ended campaign until the operator stops it. It should not stop automatically after reproducing the report result, beating a baseline, or reaching a fixed no-promotion threshold unless the operator supplies that budget or stop rule for a run.

## Consequences

- The intention source should define the objective as open-ended speedup maximization.
- Future execplan objective and run contracts should treat operator stop, budget exhaustion, or a recorded blocker as terminal conditions.
- Promotion remains incremental: a faster correct candidate with complete evidence may become `current-best`, but promotion alone does not terminate the loop.
