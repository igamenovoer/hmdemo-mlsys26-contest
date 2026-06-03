---
name: lead-code-synth-research-on-task-assignment
description: Generated on-event skill for schema_id lead-code-synth-research.email.task_assignment. Use when a coder receives a Fused MoE task assignment.
---

# Lead-Code-Synth-Research On Task Assignment

## Trigger

Exact `schema_id`: `lead-code-synth-research.email.task_assignment`.

## Owner

`coder-1`, `coder-2`, or `coder-3`.

## Procedure

1. Inspect the metadata block and payload.
2. Confirm the receiver is this coder and the requested reply is `lead-code-synth-research.email.candidate_result`.
3. Read selected context: run id, handoff id, work item id, search direction id, current-best ref, workload scope, allowed edit surface, command refs, and profile refs.
4. Perform one bounded implementation, debugging, or evidence-gathering pass.
5. Send `candidate_result` when the attempt has a reportable outcome.
6. Stop after one bounded pass. Do not wait in-chat for later work.
