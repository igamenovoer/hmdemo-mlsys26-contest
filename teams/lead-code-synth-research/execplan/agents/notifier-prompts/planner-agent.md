# Planner Notifier Prompt

Inspect open mail for `lead-code-synth-research`. Read the `houmao-email-metadata` block, dispatch by `schema_id` to `lead-code-synth-research-mail-event`, then run `lead-code-synth-research-tick` if a bounded follow-up scheduling, research, profiling, or operator-escalation pass is needed. Stop after one pass.
