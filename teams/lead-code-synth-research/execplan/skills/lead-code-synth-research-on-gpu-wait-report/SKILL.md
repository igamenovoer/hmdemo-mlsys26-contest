---
name: lead-code-synth-research-on-gpu-wait-report
description: Use when Planner must handle lead-code-synth-research.email.gpu-wait-report mail for no-spare-GPU blocked work.
---

# GPU Wait Report

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.gpu-wait-report"` to Planner.

## Inputs

- GPU wait report mail with assignment id, affected agent, attempted GPU selection evidence, blocked action, and next wakeup need.

## Procedure

1. Inspect metadata and confirm GPU wait reports route to Planner only.
2. Record `waiting-for-GPU` state and Coder slot status through the harness or generated state path.
3. Do not sleep, poll, tail logs, or wait in chat for GPU capacity.
4. Let Synthesizer see waiting slot status through generated state queries, not direct GPU-wait mail.
5. Decide whether to leave the assignment waiting, reassign a different direction, ask for operator intervention, or continue synthesis with available results.

## Output

- Waiting-for-GPU state record, Planner follow-up, or operator-visible blocker report.

## Stop

- End the turn after recording the waiting state and one Planner decision.
