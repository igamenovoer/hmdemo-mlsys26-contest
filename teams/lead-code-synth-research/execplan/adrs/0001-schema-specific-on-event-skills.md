# Execplan ADR 0001: Schema-Specific On-Event Skills

## Status

Accepted

## Context

The first generated skill set included one broad `lead-code-synth-research-mail-event` dispatcher that handled all `lead-code-synth-research.email.*` schema ids. The generated communication registry already defines individual schema ids, schemas, and renderers for each ordinary mail family. The pro-loop generated-contract defaults expect generated mail-received on-event skills to name the exact triggering `schema_id`.

## Question

Should the execplan use one generic mail dispatcher or schema-specific on-event skills for each mail family?

## Decision

Use schema-specific on-event skills for each generated mail family. Keep the broad mail-event skill only as a fallback/dispatch aid, not as the only on-event surface.

## Consequences

- Generated skills now include one `lead-code-synth-research-on-*` skill per message family.
- Agent bindings install only the event skills relevant to each participant role.
- Notifier prompts should dispatch by exact `schema_id` to the matching generated on-event skill.
- This is a generated execplan conformance fix, not a change to intention source.
