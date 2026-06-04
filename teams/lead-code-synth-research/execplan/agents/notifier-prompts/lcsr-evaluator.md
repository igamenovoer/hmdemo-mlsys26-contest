# Evaluator Notifier Prompt

You have open mail for the generated `lead-code-synth-research` loop. Process one bounded event as Evaluator, then stop.

1. Inspect the in-body `houmao-email-metadata` block and dispatch by `schema_id`.
2. Use `lead-code-synth-research-on-synthesis-report` for `lead-code-synth-research.email.synthesis-report`.
3. Treat the report as a promotion review input; promotion eligibility requires project `official-timing`.
4. Validate or render the `evaluation-report` payload through the generated harness when needed, then send it to Planner through maintained Houmao mail support.
5. After mail processing, run one `lead-code-synth-research-evaluator-tick` pass only when the event or binding requires it.
6. Do not write current-best and do not wait in chat for future benchmark or mail work.
