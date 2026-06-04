---
name: lead-code-synth-research-synthesizer-tick
description: Use when Synthesizer must perform one bounded follow-up tick for candidate aggregation or partial-result readiness in the generated lead-code-synth-research loop.
---

# Synthesizer Tick

## Trigger

- Notifier or operator prompt asks Synthesizer to perform follow-up tick work after `coder-result` mail or manual stepping.

## Inputs

- Harness `control status`, `state query --view coder-slots`, Coder result refs, and synthesis report contract.

## Procedure

1. Query control context and stop with no action if paused, stopped, or not operator-prompted in manual mode.
2. Query Coder slot status for the active cycle so waiting-for-GPU and failed slots are visible through state.
3. If available Coder evidence is sufficient, perform one select-or-merge decision and send `synthesis-report` to Evaluator and Planner.
4. If evidence is insufficient, record a bounded no-action or waiting-for-more-results note.
5. Preserve useful partial ideas without writing current-best or promoting candidates.

## Output

- One synthesis report, preserved-idea record, wait/no-action state, or no-action report.

## Stop

- End the turn after one bounded tick pass.
