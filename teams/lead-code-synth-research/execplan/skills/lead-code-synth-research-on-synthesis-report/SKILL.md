---
name: lead-code-synth-research-on-synthesis-report
description: Use when Evaluator or Planner must handle lead-code-synth-research.email.synthesis-report mail.
---

# Synthesis Report

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.synthesis-report"` to Evaluator or Planner.

## Inputs

- Synthesis report mail with selected candidate id, `project-cli` variant ref, workspace path, lineage, merge notes, rejected changes, preserved ideas, and evidence bundle refs.
- Harness control and state query surfaces.

## Procedure

1. Inspect metadata and receiver id.
2. If receiver is Planner, record the synthesis report as next-cycle context only; do not run `official-timing` and do not write current-best from synthesis evidence.
3. If receiver is Evaluator, treat the report as a promotion review input and verify candidate ref, evidence refs, edit-surface posture, and anti-hacking checklist.
4. Evaluator runs or schedules the project `official-timing` path only through explicit benchmark/evaluation commands and records command provenance.
5. Evaluator validates/renders `evaluation-report` and sends accepted or rejected promotion evidence to Planner.

## Output

- Planner context-only record, or one `evaluation-report` from Evaluator to Planner.

## Stop

- End the turn after context recording or one bounded evaluation action and report.
