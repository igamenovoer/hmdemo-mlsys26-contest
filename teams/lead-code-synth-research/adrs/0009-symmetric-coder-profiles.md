# ADR 0009: Symmetric Coder Profiles

## Status

Accepted

## Context

The first generated loop has two CUDA Coders. They could share one role profile or have specialized profiles such as local optimizer, structural optimizer, implementation Coder, or review Coder. This affects generated agent definitions, Planner assignments, and workspace expectations.

## Question

Should the two CUDA Coders use the same role profile, or should they be specialized?

## Decision

The two CUDA Coders use the same role profile. They run in parallel on different Planner-assigned optimization directions.

## Consequences

- Future agent bindings should define one CUDA Coder profile reused by CUDA Coder 1 and CUDA Coder 2.
- Planner assignments should distinguish the work directions, not the Coder personas.
- Coder workspaces remain separate so parallel work does not conflict.
- Specialized Coder roles can be added later only through a new accepted decision.
