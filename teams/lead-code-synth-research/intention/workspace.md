# Workspace

## Layout

- The first generated loop should prepare six isolated managed-agent workspaces.
- The workspace contract should support live Houmao launch and readiness validation.
- Managed-agent workspace set: Planner, CUDA Coder 1, CUDA Coder 2, Synthesizer, Researcher, and Evaluator.
- CUDA Coder 1 and CUDA Coder 2 use the same role profile but have separate workspace paths.
- Profiler does not need a workspace as a managed agent because it is a generated tool/skill surface.

## Isolation Rules

- Coder workspaces are the normal edit surfaces for candidate kernel or variant source.
- Planner, Synthesizer, Researcher, and Evaluator workspaces should not directly mutate Coder candidate source.
- Coordination should use Houmao mail, generated state records, run artifacts, and explicit evidence references rather than a shared working directory.
- Workspace paths should be distinct and validated before launch.

## Role-Local Material

- Planner workspace: assignment drafts, planning notes, cycle summaries, and current-best state write records.
- CUDA Coder workspaces: candidate source edits, local check outputs, profiler artifacts for that candidate, and Coder result evidence.
- Synthesizer workspace: candidate comparison notes, merge or selection rationale, preserved partial ideas, and synthesis reports.
- Researcher workspace: local-reference notes, network-derived references, source attribution, and research summaries.
- Evaluator workspace: promotion checks, `official-timing` evidence, anti-hacking review notes, accepted or rejected evaluation records.

## Shared State Boundary

- Shared loop state should be generated as explicit state or run artifacts, not implied by shared filesystem access.
- Generated contracts should name which agent may create, update, or consume each state record.
