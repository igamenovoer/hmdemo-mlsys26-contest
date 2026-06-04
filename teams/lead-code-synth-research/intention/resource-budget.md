# Resource Budget

## Coder Assignment Budget

- Each CUDA Coder gets one bounded attempt per assignment.
- A bounded attempt means: implement one Planner-assigned direction, run local checks if available, report evidence, then stop.
- Coders should not keep iterating in-chat after the bounded attempt.
- Planner may issue a follow-up assignment in a later cycle when the result suggests more work.

## Local Checks

- Coders should run local checks on a spare local GPU only when the workspace and environment make them available.
- Coder result evidence should state which local checks were available, which checks ran, and which checks could not run.
- Local checks are exploratory evidence and do not replace `official-timing` promotion validation.

## Follow-Up Work

- A failed or partial bounded attempt should produce evidence, failure analysis, and a recommended next step.
- Synthesizer may preserve partial ideas from bounded attempts.
- Planner owns whether to assign follow-up work in a later planning cycle.

## Still Open

- No-spare-GPU waiting and non-GPU retry policy are defined in `failure-policy.md`.
