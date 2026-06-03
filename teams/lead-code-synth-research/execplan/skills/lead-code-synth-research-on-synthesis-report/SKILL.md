---
name: lead-code-synth-research-on-synthesis-report
description: Generated on-event skill for schema_id lead-code-synth-research.email.synthesis_report. Use when the planner receives a synthesis report.
---

# Lead-Code-Synth-Research On Synthesis Report

## Trigger

Exact `schema_id`: `lead-code-synth-research.email.synthesis_report`.

## Owner

`planner`.

## Procedure

1. Inspect synthesis decision, candidate refs, and current-best update.
2. Record compact state refs through the harness when available.
3. If a candidate was promoted, choose the next search direction or request profiling.
4. If no candidate was promoted, update failed-attempt posture for the search direction.
5. Stop after one scheduling decision or state update.
