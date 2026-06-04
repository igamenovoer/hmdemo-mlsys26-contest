# ADR 0014: Spare Local GPU For Checks And Profiling

## Status

Accepted, refined by ADR 0015

## Context

The live loop needs a compute posture for Coder local checks and the Profiler tool surface. Promotion still uses the accepted `official-timing` path, but Coders and profiler commands need an exploratory environment.

## Question

What compute/timing environment should the live loop assume for Coder local checks and profiler tool use?

## Decision

The live loop should assume a local CUDA/GPU environment for Coder local checks and profiler tool use. Generated runtime or harness material should pick a spare local GPU rather than hardcoding one GPU id.

## Consequences

- Coder local checks and profiler tool calls may use local CUDA when a spare local GPU is available.
- Generated harness or instructions should include a spare-GPU selection step or GPU-id input surface.
- Local checks remain exploratory evidence and do not replace `official-timing`.
- Modal is not the default for Coder local checks or profiler use, but may remain a fallback or operator-directed path.
- ADR 0015 defines no-spare-GPU waiting and three retries for non-GPU blockers.
