# Execplan ADR 0008: CLI Tool Distribution

## Status

Accepted

## Context

The generated agent bindings defined concrete `lcsr-*` agent ids, profiles, skills, workspaces, and notifier prompts, but they did not specify which local CLI tool and Houmao project credential should launch each planned agent. The operator has two available CLI tool surfaces: Codex with project credential `codex-pro` and Claude CLI with project credential `claude-kimi-cred`. The loop should use both tools while keeping Coders, Synthesizer, and Researcher on Codex.

## Question

How should Codex credential `codex-pro` and Claude/Kimi credential `claude-kimi-cred` be distributed among the six managed agents?

## Decision

Use an implementation-focused Codex split. Launch `lcsr-cuda-coder-1`, `lcsr-cuda-coder-2`, `lcsr-synthesizer`, and `lcsr-researcher` through Codex CLI with Houmao project credential `codex-pro`. Launch `lcsr-planner` and `lcsr-evaluator` through Claude CLI with Houmao project credential `claude-kimi-cred`. This keeps Coder branches, synthesis, and research on the same Codex credential while preserving a second CLI surface for planning and evaluation.

Do not store secret key material in generated execplan artifacts. Record only credential display names, credential posture, and intended CLI launch surface.

## Consequences

- `execplan/agents/bindings.toml` now records CLI tool definitions, credential display names, and one `cli_tool` assignment per managed agent.
- Each planned profile `config.toml`, `definition.md`, and `memo-seed.md` now records the intended CLI launch surface, credential display name, and credential posture.
- Final support docs and `execplan/manifest.toml` now summarize the CLI distribution and credential boundary.
- `prepare-agents` should consume these planned CLI assignments when creating or confirming project profiles; no live profiles, credentials, or agents were changed by this decision.
