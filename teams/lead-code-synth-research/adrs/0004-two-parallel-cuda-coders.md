# ADR 0004: Two Parallel CUDA Coders

## Status

Accepted, refined by ADR 0012

## Context

The first Fused MoE loop needs a concrete Coder pool size. This affects participant bindings, mailbox routes, workspace preparation, Planner fan-out, Synthesizer aggregation, and resource budgeting.

## Question

How many CUDA Coders should the first generated loop prepare for parallel Fused MoE exploration?

## Decision

The first generated loop prepares two parallel CUDA Coders.

## Consequences

- Planner fan-out should assign at most two Coder work items per planning cycle unless the Human Operator overrides it.
- Workspace contracts should prepare two isolated Coder workspaces or branches.
- Synthesizer contracts should aggregate up to two Coder result messages per cycle.
- Resource budget per Coder was later clarified by ADR 0012.
