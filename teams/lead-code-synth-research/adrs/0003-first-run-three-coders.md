# ADR 0003: First Run Uses Three Coders

## Status

Accepted

## Context

The intention source left the number of coder agents unresolved. This decision affects participant instances, workspace contracts, task fan-out, synthesis load, and generated agent bindings for the first Fused MoE execplan.

## Question

How many coder agents should the first Fused MoE run use?

## Decision

The first run should use three coder agents.

## Consequences

- The intention source should define concrete coder instances `coder-1`, `coder-2`, and `coder-3`.
- Future execplan participant, workspace, and agent-binding surfaces should prepare one separate workspace per coder.
- The synthesizer should expect up to three parallel candidate results per planner assignment round.
