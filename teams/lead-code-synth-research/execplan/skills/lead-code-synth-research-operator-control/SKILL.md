---
name: lead-code-synth-research-operator-control
description: Use when the Human Operator or Planner must handle lifecycle, mode, recovery, status, or manual-step control for the generated lead-code-synth-research loop.
---

# Operator Control

## Trigger

- Operator asks for status, start, pause, resume, stop, recover, mode switch, invalidation, redirect, force-new-cycle, or one manual participant step for `lead-code-synth-research`.

## Inputs

- Loop slug: `lead-code-synth-research`.
- Loop dir: `teams/lead-code-synth-research`.
- Manifest: `execplan/manifest.toml`.
- Harness: `execplan/harness/bin/lead-code-synth-research-harness`.
- Future agent bindings: `execplan/agents/bindings.toml` after `execplan-agent-bindings`.

## Procedure

1. For status, run or request harness `control status`; include run state, execution mode, blockers, pending handoffs, and next operator action.
2. For mode changes, use harness `control set-mode` and route actual notifier posture changes to `houmao-agent-gateway`.
3. For pause, resume, stop, or recover, use harness control commands to record loop-local intent and route live agent prompts or interrupts to `houmao-agent-messaging` or `houmao-agent-instance` as appropriate.
4. For manual step, use `control manual-context` for the target participant, then prompt exactly one bounded participant turn through maintained messaging surfaces.
5. For ordinary mail send/read/archive, use `houmao-agent-email-comms`; the generated harness only validates, renders, queries, and records loop-local facts.
6. Do not launch agents, create workspaces, mutate gateway state, or send mail from this skill unless the matching maintained Houmao platform skill is explicitly invoked in a later execution stage.

## Output

- Control status, mode record, pause/resume/stop/recovery intent record, manual-step context, or platform-routing instruction.

## Stop

- End the turn after one bounded control action or one status report.
