---
name: lead-code-synth-research-on-optimization-assignment
description: Use when a CUDA Coder must handle lead-code-synth-research.email.optimization-assignment mail for one bounded assignment.
---

# Optimization Assignment

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.optimization-assignment"` to `cuda-coder-1` or `cuda-coder-2`.

## Inputs

- Received assignment mail.
- Coder workspace and allowed edit surface from the payload.
- Harness command for email validation, state query, and record application.
- Domain CUDA skills available to the Coder when implementation work begins.

## Procedure

1. Inspect the metadata block and verify receiver id, `cycle_id`, `assignment_id`, Coder slot, current-best ref, allowed edit surface, direction, evidence expectations, and risk notes.
2. Query `control status` or `control manual-context` when prompted manually, and stop if the run is paused, stopped, or not actionable.
3. Perform one bounded implementation attempt in the isolated Coder workspace; produce or update a `project-cli` variant id or variant directory ref.
4. If GPU-dependent local checks are useful, pick a spare local GPU dynamically; if none is available, record waiting-for-GPU state and send `gpu-wait-report` to Planner through maintained mail support.
5. For non-GPU blockers, use the retry posture from state or Planner context; after three failed retries or an unrecoverable blocker, send `failure-report` to Planner.
6. When the bounded attempt completes, validate/render `coder-result` and send it to Synthesizer only.

## Output

- One `coder-result` to Synthesizer, or one `gpu-wait-report` or `failure-report` to Planner.

## Stop

- End the turn after one bounded attempt and its report; do not continue iterative optimization in-chat.
