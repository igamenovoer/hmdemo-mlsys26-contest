---
name: lead-code-synth-research-on-planning-cycle-start
description: Use when Planner must handle lead-code-synth-research.email.planning-cycle-start mail for the generated lead-code-synth-research loop.
---

# Planning Cycle Start

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.planning-cycle-start"`.

## Inputs

- Received `planning-cycle-start` mail and its `houmao-email-metadata` block.
- Harness: `execplan/harness/bin/lead-code-synth-research-harness`.
- Contracts: `specs/comms/templates.toml`, `specs/collab/loop-policy.toml`, `specs/state/schema.sql`.

## Procedure

1. Inspect the metadata block and confirm the schema id, run id, payload id, sender id, and receiver id are for Planner.
2. Use `email schema planning-cycle-start` or `context query --message-family planning-cycle-start` when route or carried context is unclear.
3. Query `control status` and stop with a no-action report if the run is paused, stopped, or manual mode without an operator prompt.
4. Open or resume one planning cycle from the current-best ref and history refs, choose up to two distinct Coder directions, and record cycle or assignment state through the harness when record surfaces exist.
5. Render and send one `optimization-assignment` mail per selected Coder through maintained Houmao mail support.
6. Archive or close the source mail only after successful processing when the active mail policy requires it.

## Output

- Up to two `optimization-assignment` handoffs, cycle state records, or a no-action report.

## Stop

- End the turn after dispatching the bounded planning work or reporting why no assignment was issued.
