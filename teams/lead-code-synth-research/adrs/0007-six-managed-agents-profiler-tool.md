# ADR 0007: Six Managed Agents With Profiler Tool

## Status

Accepted

## Context

The loop needs a concrete Houmao managed-agent roster. The paper describes Planner, CUDA Coders, Synthesizer, Profiler, Researcher, Evaluator, and Human Operator roles, but not every role must be launched as a live managed agent.

## Question

Which concrete Houmao agent roster should the first generated loop prepare?

## Decision

The first generated loop prepares six managed agents: Planner, CUDA Coder 1, CUDA Coder 2, Synthesizer, Researcher, and Evaluator. The Profiler is a generated tool/skill surface, not a live managed agent.

## Consequences

- Future agent bindings should prepare six managed Houmao agents.
- Profiling behavior should be generated as harness commands, skills, or tool instructions invoked by managed agents.
- The workflow should not require mailbox delivery to a separate Profiler agent.
- Future execplan communication contracts should model profiler evidence as tool output or attached artifacts rather than ordinary participant mail from a Profiler agent.
