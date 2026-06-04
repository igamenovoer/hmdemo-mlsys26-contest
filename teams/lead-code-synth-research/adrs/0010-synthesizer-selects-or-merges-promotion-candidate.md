# ADR 0010: Synthesizer Selects Or Merges Promotion Candidate

## Status

Accepted, refined by ADR 0011

## Context

The Synthesizer receives outputs from two symmetric CUDA Coders. It can merely compare results, select one output, merge useful changes into a promotion candidate, or leave all promotion candidate preparation to Coders or the Evaluator. This affects source-edit authority, candidate lineage, Evaluator inputs, and mail routing.

## Question

What should the Synthesizer be allowed to do with Coder outputs?

## Decision

The Synthesizer may select or merge Coder outputs into a promotion candidate. The Evaluator alone validates promotion eligibility after `official-timing`; ADR 0011 assigns current-best state writes to Planner.

## Consequences

- Synthesizer contracts should allow both selection and merge/combination work.
- Synthesizer output should identify source Coder candidates, merged changes, conflict decisions, and preserved ideas.
- Evaluator contracts should treat Synthesizer output as a submitted promotion candidate, not as an already-promoted result.
- Planner contracts should write current-best state only after accepted Evaluator evidence.
- `official-timing` remains the promotion gate.
