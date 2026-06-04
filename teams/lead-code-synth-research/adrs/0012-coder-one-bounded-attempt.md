# ADR 0012: Coder One Bounded Attempt

## Status

Accepted, refined by ADR 0015

## Context

The loop needs a per-assignment budget for each CUDA Coder. This affects timeout handling, retry semantics, Coder result expectations, Synthesizer aggregation, and Planner fan-out.

## Question

What budget should each CUDA Coder get per assignment?

## Decision

Each CUDA Coder gets one bounded attempt per assignment: implement one assigned direction, run local checks if available, report evidence, then stop.

## Consequences

- Generated Coder skills should perform one bounded implementation pass and not continue looping in-chat.
- Coder result mail should report whether local checks were available and which checks ran.
- Planner may assign a new follow-up work item in a later cycle, but the current Coder turn ends after the bounded attempt.
- Synthesizer should aggregate up to two bounded Coder results per cycle.
- ADR 0015 defines no-spare-GPU waiting and three retries for non-GPU blockers.
