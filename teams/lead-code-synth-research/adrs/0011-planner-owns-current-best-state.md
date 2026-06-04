# ADR 0011: Planner Owns Current-Best State

## Status

Accepted

## Context

The loop needs one owner for durable current-best candidate state. The Evaluator runs `official-timing` and produces promotion evidence, while Planner starts each cycle from current-best state and run history.

## Question

Which agent should own writes to the current-best candidate state?

## Decision

Planner owns writes to current-best state. Evaluator sends promotion evidence to Planner after `official-timing`.

## Consequences

- Evaluator validates promotion eligibility and sends accepted or rejected evaluation evidence.
- Planner writes current-best state after receiving accepted Evaluator promotion evidence.
- Synthesizer-submitted candidates are promotion submissions, not current-best updates.
- Generated state contracts should give Planner write authority for current-best and read authority to Coders, Synthesizer, Researcher, and Evaluator.
- Generated validation should reject current-best writes from non-Planner agents.
