---
name: lead-code-synth-research-on-operator-escalation
description: Generated on-event skill for schema_id lead-code-synth-research.email.operator_escalation. Use when the operator receives escalation after research-assisted failure.
---

# Lead-Code-Synth-Research On Operator Escalation

## Trigger

Exact `schema_id`: `lead-code-synth-research.email.operator_escalation`.

## Owner

`operator`.

## Procedure

1. Inspect the failed search direction, failed attempt summary, research brief refs, and requested operator decision.
2. Decide whether to redirect, repair, override, stop, or continue.
3. Send `search_correction` to `planner` when continuing the run.
4. Use maintained Houmao platform skills for prompting, notifier, mailbox, lifecycle, or gateway mechanics.
