---
name: lead-code-synth-research-mail-event
description: Generated on-event handler for templated lead-code-synth-research mail. Use when a bound participant receives loop mail with a lead-code-synth-research schema_id.
---

# Lead-Code-Synth-Research Mail Event

## Trigger

Use this skill when received mail contains a `houmao-email-metadata` block whose `schema_id` starts with `lead-code-synth-research.email.`.

## Procedure

1. Inspect the in-body metadata block and identify the exact `schema_id`.
2. Match the `schema_id` to `execplan/specs/comms/templates.toml`.
3. Process one bounded event for the receiver role.
4. Preserve required context from the payload, including run id, handoff id, work item id, search direction id, candidate refs, evidence refs, and selected predecessor refs.
5. Send the expected reply family when the template registry names one.
6. Record or reference state and run artifacts through generated harness surfaces when available.
7. Stop after one bounded event. Do not sleep, poll, tail logs, or wait in-chat for later mail.

## Role Notes

- Planner handles task assignment, profile requests, research requests, operator escalation, and search correction.
- Coders handle task assignment and return `candidate_result`.
- Synthesizer handles `candidate_result` and returns `synthesis_report`.
- Profiler handles `profile_request` and returns `profile_report`.
- Researcher handles `research_request` and returns `research_brief`.
