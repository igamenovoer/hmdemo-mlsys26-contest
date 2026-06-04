# Agent Roster

## Managed Agents

- Planner.
- CUDA Coder 1, using the shared CUDA Coder profile.
- CUDA Coder 2, using the same shared CUDA Coder profile.
- Synthesizer.
- Researcher.
- Evaluator.

## Tool Surfaces

- Profiler is a generated tool/skill surface, not a managed agent.
- Profiling outputs should be attached to Coder, Planner, Synthesizer, or Evaluator work as artifacts or structured evidence.
- Profiling should not require a separate Profiler mailbox or live-agent session.

## Binding Implications

- Prepare six isolated managed-agent workspaces, one for each managed agent.
- Prepare Planner workspace material for assignment and history review.
- Prepare two Coder workspaces for candidate source edits and local evidence.
- Use one CUDA Coder profile for both Coder agents; Planner assignments provide different optimization directions per cycle.
- Prepare Synthesizer workspace material for candidate comparison and merge/selection work.
- Prepare Researcher workspace material for concurrent local-and-network research.
- Prepare Evaluator workspace material for promotion checks, anti-hacking review, and official-timing evidence.
- Use generated state, run artifacts, and Houmao mail for coordination instead of a shared coordination workspace.
- Generated skills should expose profiling commands or instructions to the managed agents that need profiling evidence.
