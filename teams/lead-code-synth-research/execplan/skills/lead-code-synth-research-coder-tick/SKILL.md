---
name: lead-code-synth-research-coder-tick
description: Use when a CUDA Coder must perform one bounded follow-up tick for assignment state, retry, or manual context in the generated lead-code-synth-research loop.
---

# Coder Tick

## Trigger

- Notifier or operator prompt asks `cuda-coder-1` or `cuda-coder-2` to perform follow-up tick work.

## Inputs

- Harness `control status`, optional `control manual-context`, and current assignment/mail refs.

## Procedure

1. Query control context and stop with no action if the run is paused, stopped, or manual mode without an operator prompt.
2. If there is an active assignment retry allowed by Planner/state, perform one bounded retry step only.
3. If waiting for GPU and this prompt is a later wakeup, retry dynamic spare-GPU selection once; if unavailable, refresh waiting-for-GPU evidence and stop.
4. If no actionable assignment exists, report no action.
5. Do not start new optimization work without a fresh `optimization-assignment`.

## Output

- One refreshed blocker report, one bounded retry result, one Coder result, or a no-action report.

## Stop

- End the turn after one bounded tick pass.
