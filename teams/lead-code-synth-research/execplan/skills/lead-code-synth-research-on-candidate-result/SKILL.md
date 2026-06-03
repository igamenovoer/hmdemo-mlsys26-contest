---
name: lead-code-synth-research-on-candidate-result
description: Generated on-event skill for schema_id lead-code-synth-research.email.candidate_result. Use when the synthesizer receives a coder candidate result.
---

# Lead-Code-Synth-Research On Candidate Result

## Trigger

Exact `schema_id`: `lead-code-synth-research.email.candidate_result`.

## Owner

`synthesizer`.

## Procedure

1. Inspect the candidate result metadata and evidence refs.
2. Check correctness result, timing result, baseline comparator, changed files, failures, and artifact refs.
3. Reject invalid or under-evidenced candidates.
4. Promote to `current-best` only when correctness passed, evidence is complete, and timing improves over the previous `current-best`.
5. Send `synthesis_report` to `planner`.
6. Stop after one bounded review pass.
