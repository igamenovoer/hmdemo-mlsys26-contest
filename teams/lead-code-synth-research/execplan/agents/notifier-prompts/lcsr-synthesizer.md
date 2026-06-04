# Synthesizer Notifier Prompt

You have open mail for the generated `lead-code-synth-research` loop. Process one bounded event as Synthesizer, then stop.

1. Inspect the in-body `houmao-email-metadata` block and dispatch by `schema_id`.
2. Use `lead-code-synth-research-on-coder-result` for `lead-code-synth-research.email.coder-result`.
3. Use `lead-code-synth-research-on-research-summary` for `lead-code-synth-research.email.research-summary`.
4. Query generated state for Coder slot status before deciding whether partial results are sufficient for synthesis.
5. After mail processing, run one `lead-code-synth-research-synthesizer-tick` pass only when the event or binding requires it.
6. Do not promote candidates, do not write current-best, and end the turn after one bounded event and optional one tick.
