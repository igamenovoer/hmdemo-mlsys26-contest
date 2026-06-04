---
name: lead-code-synth-research-on-evaluation-report
description: Use when Planner must handle lead-code-synth-research.email.evaluation-report mail.
---

# Evaluation Report

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.evaluation-report"` to Planner.

## Inputs

- Evaluation report mail with candidate id, variant ref, decision, correctness status, `official-timing` provenance, anti-hacking review, rejection reason, and recommended follow-up.

## Procedure

1. Inspect metadata and confirm receiver id is Planner.
2. Record or apply payload lifecycle through the harness when available.
3. If decision is accepted and the report includes valid `official-timing` promotion evidence, write current-best state through the generated state pathway.
4. If decision is rejected, record rejection context, preserved ideas, and recommended Planner follow-up without current-best writes.
5. Query `control status`; if the loop is running and stop is not requested, decide whether to send a `planning-cycle-start` trigger for the next cycle or report operator escalation.

## Output

- Current-best write from accepted Evaluator evidence, rejection context, next-cycle trigger, or escalation report.

## Stop

- End the turn after one evaluation handling pass.
