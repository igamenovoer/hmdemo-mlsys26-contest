# Evaluation

## Promotion Rule

- Coder exploration may use local checks for fast iteration.
- A candidate can become eligible for current-best update only after the Evaluator confirms it through the project `official-timing` path.
- Local timing, local correctness checks, and profiler evidence may support a submission for promotion, but they do not promote the candidate by themselves.
- Evaluator promotion evidence lets Planner update current-best state; Evaluator does not write current-best state directly.
- Synthesizer-selected or Synthesizer-merged candidates are promotion submissions, not promoted results.

## Evidence Classes

- Exploratory evidence: local correctness checks, local timing, compile results, Coder notes, and profiler hints gathered during implementation.
- Promotion evidence: `official-timing` result, correctness status, speedup or latency comparison against the previous best, candidate id, variant or workspace path, command provenance, and changed-file summary.
- Rejection evidence: correctness failure, timeout, benchmark invalidity, anti-hacking concern, regression, irreproducible result, or insufficient promotion evidence.

## Candidate States

- Exploratory: a Coder is iterating locally.
- Submitted for promotion: a candidate has enough local evidence for Evaluator review.
- Promotion evidence accepted: `official-timing` accepts the candidate and Evaluator sends evidence to Planner.
- Current-best updated: Planner records the accepted candidate as current-best.
- Rejected: the Evaluator rejects the candidate with a recorded reason.
- Preserved idea: the Synthesizer keeps a partial idea from a rejected candidate for future Planner context.

## Completion Relationship

- Evaluation decides promotion eligibility, not loop completion or current-best writes.
- Loop completion is controlled only by a manual Human Operator stop.
