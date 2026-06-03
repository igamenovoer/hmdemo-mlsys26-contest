---
name: lead-code-synth-research-on-profile-request
description: Generated on-event skill for schema_id lead-code-synth-research.email.profile_request. Use when the profiler receives a profile request.
---

# Lead-Code-Synth-Research On Profile Request

## Trigger

Exact `schema_id`: `lead-code-synth-research.email.profile_request`.

## Owner

`profiler`.

## Procedure

1. Inspect the requested current-best or candidate ref, workload scope, command refs, and requested metrics.
2. Run one bounded profiling pass using the provided or operator-bound profiling command.
3. Store profile artifacts under the run artifact layout.
4. Send `profile_report` to `planner`.
5. Stop after one bounded profiling/reporting pass.
