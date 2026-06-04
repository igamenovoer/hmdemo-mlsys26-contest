# Failure Policy

## GPU Capacity

- If no spare local GPU is available for a GPU-dependent Coder check or Profiler tool call, the work should enter a waiting-for-GPU state.
- Waiting for GPU means recording the blocked assignment, affected agent, attempted GPU selection evidence, and next wakeup need.
- Agents should not sleep, poll, or wait inside one chat turn.
- A later notifier or operator wakeup should retry GPU selection and continue the bounded attempt when a spare GPU is available.

## Non-GPU Blockers

- Non-GPU blockers may be retried up to three times.
- Examples include command failure that looks transient, workspace readiness hiccups, malformed mail or missing refs that can be repaired, and incomplete agent replies.
- After three failed retries, the agent or loop should report failure rather than continuing automatic retries.

## Failure Report

- Assignment id, agent id, and candidate id when applicable.
- Blocker type: no spare GPU, command failure, workspace problem, malformed input, missing evidence, crash, timeout, or other.
- Retry count and retry evidence.
- Local checks or profiler work completed before the blocker.
- Recommended Planner follow-up.

## Synthesis Behavior

- Synthesizer may continue with available Coder results when another assignment is waiting for GPU or has failed after retries.
- Planner decides whether to reassign, redirect, preserve partial findings, or wait for GPU capacity in a later cycle.
