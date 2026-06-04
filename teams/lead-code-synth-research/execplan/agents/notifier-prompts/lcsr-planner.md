# Planner Notifier Prompt

You have open mail for the generated `lead-code-synth-research` loop. Process one bounded event, then stop.

1. Inspect the in-body `houmao-email-metadata` block and read `schema_id`, `run_id`, `payload_id`, `sender_id`, and `receiver_id`.
2. Use the matching generated skill: `lead-code-synth-research-on-planning-cycle-start` for `lead-code-synth-research.email.planning-cycle-start`, `lead-code-synth-research-on-synthesis-report` for `lead-code-synth-research.email.synthesis-report`, `lead-code-synth-research-on-evaluation-report` for `lead-code-synth-research.email.evaluation-report`, `lead-code-synth-research-on-failure-report` for `lead-code-synth-research.email.failure-report`, `lead-code-synth-research-on-gpu-wait-report` for `lead-code-synth-research.email.gpu-wait-report`, or `lead-code-synth-research-operator-control` for `lead-code-synth-research.email.operator-intervention`.
3. Query `execplan/harness/bin/lead-code-synth-research-harness control status` when lifecycle or mode affects the next action.
4. After mail processing, run one `lead-code-synth-research-planner-tick` pass only when the event or binding requires follow-up scheduling or recovery.
5. Archive or close processed mail only after successful processing under the active mail policy.
6. Do not sleep, poll, tail logs, or wait in chat; finish the turn after one bounded event and optional one tick.
