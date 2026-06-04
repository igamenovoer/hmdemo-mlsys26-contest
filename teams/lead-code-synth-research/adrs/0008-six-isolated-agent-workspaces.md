# ADR 0008: Six Isolated Agent Workspaces

## Status

Accepted

## Context

The first generated loop has six managed agents. The workspace layout can either isolate every role, share coordination roles, or put all agents in one shared workspace. This decision affects workspace-manager contracts, write permissions, evidence routing, and conflict prevention.

## Question

How should the six managed agents share or isolate workspaces?

## Decision

Each of the six managed agents gets its own isolated workspace.

## Consequences

- Future workspace contracts should prepare six isolated workspaces: Planner, CUDA Coder 1, CUDA Coder 2, Synthesizer, Researcher, and Evaluator.
- Coordination should happen through generated state, run artifacts, and Houmao mail rather than a shared working directory.
- Coder workspaces remain the only normal places for candidate kernel edits.
- Planner, Synthesizer, Researcher, and Evaluator workspaces should store role-local notes, reports, downloaded references when allowed, and generated evidence, but should not directly mutate Coder candidate source.
- Generated validation should check that workspace paths are distinct before launch.
