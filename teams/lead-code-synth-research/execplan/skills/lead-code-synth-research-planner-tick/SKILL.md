---
name: lead-code-synth-research-planner-tick
description: Use when Planner must perform one bounded follow-up tick for scheduling, recovery, control, or next-cycle decisions in the generated lead-code-synth-research loop.
---

# Planner Tick

## Trigger

- Notifier or operator prompt asks Planner to perform follow-up tick work after mail processing or manual stepping.

## Inputs

- Harness `control status`, `state query`, `topology query`, and active mail context.

## Procedure

1. Query `control status`; if run state is stopped or paused, record no action unless the prompt is an operator recovery/control prompt.
2. Branch on execution mode: in `auto`, process one notifier-prompted follow-up; in `manual`, use `control manual-context --participant-id planner` and do one operator-prompted pass.
3. Choose at most one action: dispatch a next planning cycle, handle one blocker, retry one waiting-for-GPU record after wakeup, record synthesis context, apply an operator control, or report no action.
4. Use generated harness commands for state reads or controlled record application.
5. Route platform mail or prompts through maintained Houmao skills, not the harness.

## Output

- One next-cycle trigger, one recovery action, one control record, or a no-action report.

## Stop

- End the turn after one bounded tick pass.
