# Communication Overview

Ordinary participant communication is schema-typed Houmao mail. The `schema_id` in the in-body `houmao-email-metadata` header is the loop-local event type, and generated on-event skills must dispatch on exact `schema_id` rather than subject text, sender identity, or hidden transport headers.

Outgoing templated mail follows `TOML payload -> JSON Schema validation -> Markdown rendering -> Houmao mail delivery`. Harness generation may add commands for schema lookup, payload validation, rendering, record application, and query, but mailbox delivery remains owned by maintained Houmao mail and messaging skills.

Each generated renderer starts with a parseable `houmao-email-metadata` fenced block containing `schema_id`, `schema_version`, `kind`, `run_id`, `plan_revision`, `payload_id`, `sender_id`, `receiver_id`, and `route_id` when applicable. Rendered mail then includes readable context, requested action, predecessor refs, evidence refs, and reply or forward expectations selected by the process model.

Normal route decisions are fixed by the process contracts: `coder-result` routes to Synthesizer only; `gpu-wait-report` and `failure-report` route to Planner only; `synthesis-report` routes to Evaluator and Planner, with Planner context-only; `evaluation-report` routes to Planner for accepted or rejected promotion evidence; Researcher replies to the requester and may forward selected planning-relevant ideas to Planner when the requester is not Planner.

Unknown-schema, malformed, unsupported, or freeform operator mail enters a generated fallback or repair path in later skill and harness stages. Agents must process one bounded event, optionally perform one bounded tick pass when prompted, and then stop the turn.
