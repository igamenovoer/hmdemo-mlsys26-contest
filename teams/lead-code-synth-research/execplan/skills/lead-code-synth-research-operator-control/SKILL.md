---
name: lead-code-synth-research-operator-control
description: Generated operator-control skill for lifecycle, mode, stop, override, repair, and recovery semantics for the lead-code-synth-research loop.
---

# Lead-Code-Synth-Research Operator Control

## Identity

- Loop slug: `lead-code-synth-research`
- Loop dir: `teams/lead-code-synth-research`
- Manifest: `execplan/manifest.toml`
- Harness: `execplan/harness/commands.toml`
- Agent bindings: `execplan/agents/bindings.toml`

## Supported Controls

- Start after prepared agents, workspace readiness, validation, launch, and live-agent/session facts exist.
- Switch execution mode between `auto` and `manual`.
- Pause, resume, stop, override, repair, and recover by recording operator intent events.
- Send search correction to planner after escalation.

## Platform Boundaries

Use maintained Houmao skills for platform mechanics: agent preparation, workspace preparation, mailbox setup, gateway and notifier posture, live launch, prompting, mail delivery, lifecycle inspection, and memory posture. This generated skill owns loop-local semantics only.

## Manual Mode

Manual mode is not paused. It means notifier wakeups are suspended or disabled for the loop and the operator prompts one bounded participant turn at a time.
