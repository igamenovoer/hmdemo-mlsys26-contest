# Synthesis

## Authority

- The Synthesizer may select one Coder output as a promotion candidate.
- The Synthesizer may merge useful changes or ideas from multiple Coder outputs into one promotion candidate.
- The Synthesizer may preserve useful partial ideas from rejected or incomplete candidates for future Planner context.
- The Synthesizer does not promote candidates or write current-best state; Evaluator validates promotion eligibility through `official-timing`, and Planner writes current-best state.

## Required Output

- Source Coder candidate ids and workspace refs.
- Selected or merged candidate id.
- Summary of changes included in the candidate.
- Merge conflicts or compatibility concerns.
- Rejected changes and reasons.
- Preserved ideas for future cycles.
- Evidence bundle refs for Evaluator review.

## Boundaries

- Synthesizer work should not mutate Coder workspaces directly without an explicit generated workflow path.
- Evaluator may reject a Synthesizer candidate for correctness, performance, anti-hacking, reproducibility, or insufficient evidence.
- Planner should receive accepted Evaluator promotion evidence and useful rejected ideas as future context.
