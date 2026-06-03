# ADR 0004: Synthesizer Promotes Current Best

## Status

Accepted

## Context

The intention source said the synthesizer selects or merges the strongest result, but it did not define promotion authority or the success condition for candidate acceptance. This decision affects result routing, candidate lifecycle, state updates, evidence validation, and operator-control semantics.

## Question

Who accepts a Fused MoE candidate as promoted, and what is the success condition?

## Decision

The synthesizer promotes faster correct candidates. A candidate may become `current-best` when it passes correctness checks, supplies complete evidence, and improves timing over the previous `current-best`. The operator controls terminal stop and override decisions.

## Consequences

- The intention source should name the synthesizer as the normal promotion authority for candidate results.
- Future execplan state and communication contracts should let the synthesizer update `current-best` after validating correctness, evidence, and timing.
- Operator-control surfaces should retain stop, override, repair, and search-correction authority without requiring operator approval for every normal promotion.
