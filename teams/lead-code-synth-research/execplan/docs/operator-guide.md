# Operator Guide

## Purpose

Explain the generated execution stages for the `lead-code-synth-research` Fused MoE loop.

## Stages

1. `prepare-agents`: prepare project profiles, generated skill bindings, prompt sources, notifier prompts, memo posture, and prepared agent facts. This stage does not launch agents.
2. `prepare-workspace`: use prepared agent/profile facts plus `specs/workspace/workspace.toml` to plan, create, validate, or summarize workspaces through `houmao-utils-workspace-mgr`.
3. `validate-loop`: check prepared agents, workspace readiness or manual evidence, mailbox/gateway/notifier posture, harness availability, run artifact posture, launchability, and no in-chat waiting posture.
4. `launch-agents`: launch prepared participants through maintained Houmao launch surfaces and report live-agent/session facts. This stage does not start loop work.
5. `start`: send the first loop trigger after live-agent/session facts exist.

## Runtime Inputs

Before `start`, provide Fused MoE workload scope, allowed edit surface, correctness command, timing command, initial current-best or baseline ref, and optional profiling command. The generated objective contract leaves these as run setup inputs.

## Control

Default execution mode is `auto`. Use the operator-control skill to switch to `manual`, pause, resume, stop, override, repair, recover, or send search correction. Notifier posture changes, managed-agent prompting, mailbox delivery, and live lifecycle operations stay with maintained Houmao skills.
