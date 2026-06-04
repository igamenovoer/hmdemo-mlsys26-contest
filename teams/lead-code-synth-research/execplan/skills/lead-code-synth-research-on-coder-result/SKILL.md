---
name: lead-code-synth-research-on-coder-result
description: Use when Synthesizer must handle lead-code-synth-research.email.coder-result mail from a CUDA Coder.
---

# Coder Result

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.coder-result"` to Synthesizer.

## Inputs

- Coder result mail with candidate id, assignment id, `project-cli` variant ref, workspace path, changed files, commands run, evidence refs, and recommended follow-up.
- Harness state query for sibling Coder slot status.

## Procedure

1. Inspect metadata and confirm the mail routes to Synthesizer only.
2. Semantically inspect the candidate evidence and record or apply payload lifecycle through the harness when available.
3. Query `state query --view coder-slots` for the cycle so waiting-for-GPU and failed sibling slots are visible through state, not direct blocker mail.
4. If available Coder evidence is insufficient, record a bounded no-action or waiting-for-more-results state and stop.
5. If evidence is sufficient, select or merge a promotion candidate, preserve useful rejected ideas, and ensure the selected output carries a `project-cli` variant id or variant directory ref, workspace path, lineage, and evidence refs.
6. Validate/render `synthesis-report` and send it to Evaluator and Planner; Planner's copy is context only.

## Output

- One `synthesis-report` to Evaluator and Planner, or a recorded wait/no-action report.

## Stop

- End the turn after one synthesis decision or one no-action record.
