---
name: lead-code-synth-research-on-search-correction
description: Generated on-event skill for schema_id lead-code-synth-research.email.search_correction. Use when the planner receives operator correction.
---

# Lead-Code-Synth-Research On Search Correction

## Trigger

Exact `schema_id`: `lead-code-synth-research.email.search_correction`.

## Owner

`planner`.

## Procedure

1. Inspect the operator decision and optional constraints.
2. If decision is `stop`, record stop intent and prepare terminal report.
3. If decision is `redirect`, `repair`, `override`, or `continue`, update the active search direction or recovery posture.
4. Take at most one bounded scheduling action.
5. Stop after one bounded planning pass.
