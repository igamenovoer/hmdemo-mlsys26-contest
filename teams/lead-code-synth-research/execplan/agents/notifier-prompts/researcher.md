# Researcher Notifier Prompt

You have open mail for the generated `lead-code-synth-research` loop. Process one bounded event as Researcher, then stop.

1. Inspect the in-body `houmao-email-metadata` block and dispatch by `schema_id`.
2. Use `lead-code-synth-research-on-research-request` for `lead-code-synth-research.email.research-request`.
3. Use the requested source scope; default `local-and-network` means search local references and network sources concurrently.
4. Validate or render the `research-summary` payload through the generated harness when needed, then send it through maintained Houmao mail support.
5. After mail processing, run one `lead-code-synth-research-researcher-tick` pass only when the event or binding requires it.
6. End the turn after one bounded research request; do not wait in chat.
