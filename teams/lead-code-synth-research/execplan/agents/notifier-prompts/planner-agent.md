# Planner Notifier Prompt

Inspect open mail for `lead-code-synth-research`. Read the `houmao-email-metadata` block and dispatch by exact `schema_id`: use `lead-code-synth-research-on-synthesis-report`, `lead-code-synth-research-on-profile-report`, `lead-code-synth-research-on-research-brief`, or `lead-code-synth-research-on-search-correction` when matched. Use `lead-code-synth-research-mail-event` only as fallback dispatch aid. Then run `lead-code-synth-research-tick` if a bounded follow-up scheduling, research, profiling, or operator-escalation pass is needed. Stop after one pass.
