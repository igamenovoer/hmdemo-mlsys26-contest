# ADR 0015: GPU Wait And Other Blockers Three Retries

## Status

Accepted

## Context

The live loop needs a retry and waiting policy for missing, crashed, incomplete, blocked, or no-GPU agent work. Earlier decisions require bounded Coder turns and spare local GPU selection, so this policy must avoid in-chat sleeping while still allowing GPU-dependent work to wait for capacity.

## Question

What should happen when an agent reply is missing, crashed, incomplete, or blocked by no spare GPU?

## Decision

For no spare GPU, the agent should enter a recorded waiting-for-GPU posture and retry after a later wakeup rather than failing the assignment. For non-GPU blockers, the loop should retry up to three times and report failure if the blocker remains.

## Consequences

- No-spare-GPU conditions are not immediate assignment failures.
- Generated state should record waiting-for-GPU facts, affected agent, assignment id, and last attempted GPU selection evidence.
- Agents must not sleep, poll, or wait inside one chat turn; waiting-for-GPU is a loop state that requires a later notifier or operator wakeup.
- Non-GPU blockers get at most three retry attempts before a failure report.
- Failure reports should include attempted retries, blocker type, evidence, and recommended Planner follow-up.
