# State

## Current-Best Candidate

- Planner owns writes to current-best candidate state.
- Evaluator sends promotion evidence to Planner after `official-timing`.
- Planner updates current-best state only from accepted Evaluator promotion evidence.
- Coders, Synthesizer, Researcher, and Evaluator may read current-best state.
- Synthesizer candidates and Evaluator promotion evidence are not current-best writes by themselves.

## State Records

- Current-best candidate id, source refs, workspace refs, and variant refs.
- Accepted Evaluator promotion evidence and `official-timing` provenance.
- Previous-best comparison and speedup or latency summary.
- Candidate lineage from Coder outputs and Synthesizer merge or selection notes.
- Rejected candidates, invalid-speedup findings, and preserved ideas for future planning.

## Ownership

- Planner writes current-best state and planning-cycle state.
- Evaluator writes evaluation evidence and promotion recommendations.
- Synthesizer writes synthesis reports and promotion-candidate submissions.
- Coders write Coder result evidence for their own assignments.
- Researcher writes research summaries and source-scope notes.
