---
name: lead-code-synth-research-on-failure-report
description: Use when Planner must handle lead-code-synth-research.email.failure-report mail after non-GPU retry exhaustion or another unrecoverable blocker.
---

# Failure Report

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.failure-report"` to Planner.

## Inputs

- Failure report mail with assignment id, agent id, blocker type, retry count, retry evidence, completed work refs, and recommended follow-up.

## Procedure

1. Inspect metadata and confirm failure reports route to Planner only.
2. Record failed Coder slot or blocker status in generated state so Synthesizer can query it without direct failure mail.
3. If retry count is below three and the blocker is retryable, record retry-needed state instead of failure-final posture.
4. After three retries or unrecoverable failure, decide one Planner follow-up: reassign, redirect, preserve partial findings, ask Researcher, or escalate to operator.
5. Send any follow-up mail required by that one decision and stop.

## Output

- Planner recovery record, follow-up handoff, or operator escalation report.

## Stop

- End the turn after one recovery decision.
