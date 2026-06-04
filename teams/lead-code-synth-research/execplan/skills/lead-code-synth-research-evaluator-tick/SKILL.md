---
name: lead-code-synth-research-evaluator-tick
description: Use when Evaluator must perform one bounded follow-up tick for promotion review or manual context in the generated lead-code-synth-research loop.
---

# Evaluator Tick

## Trigger

- Notifier or operator prompt asks Evaluator to perform follow-up tick work after `synthesis-report` mail or manual stepping.

## Inputs

- Harness `control status`, synthesis report refs, candidate `project-cli` variant ref, workspace path, and promotion policy.

## Procedure

1. Query control context and stop with no action if paused, stopped, or manual mode without an operator prompt.
2. If one promotion submission is pending, validate candidate refs, edit surface, evidence bundle, and anti-hacking posture.
3. Run or schedule `official-timing` only through explicit project evaluation commands and record command provenance.
4. Send one `evaluation-report` to Planner with accepted or rejected status.
5. If no promotion submission is pending, report no action.

## Output

- One evaluation report or no-action report.

## Stop

- End the turn after one bounded tick pass.
