# Operator Guide

This generated support guide summarizes how to move from finalized execplan material to a live Houmao loop. It is not a platform operation record and it does not create profiles, workspaces, mailboxes, gateways, or live agents.

## Entry Points

- Start with `../manifest.toml` for package status and omissions.
- Use `../specs/objective/objective.toml` and `../specs/objective/policy.toml` for the Fused MoE objective, correctness gate, anti-hacking policy, retry policy, and GPU posture.
- Use `../agents/bindings.toml` for the planned `lcsr-*` concrete agent ids, CLI tool assignment, generated skill assignment, full runtime skill assignment, profile paths, notifier prompts, and workspace policy refs.
- Use `../specs/workspace/workspace.toml` when preparing isolated in-repo Git worktree workspaces for `lcsr-planner`, `lcsr-cuda-coder-1`, `lcsr-cuda-coder-2`, `lcsr-synthesizer`, `lcsr-researcher`, and `lcsr-evaluator`.
- Use `../harness/bin/lead-code-synth-research-harness` for loop-local validation, schema lookup, mail rendering, sqlite state, and control-state commands.

## Execution Stages

1. Run `validate-execplan` to check generated package shape and contract consistency.
2. Run `prepare-agents` to create or confirm the concrete Houmao profiles and generated skill bindings.
3. Run `prepare-workspace` to create or validate the six isolated workspaces and shared owner-state material.
4. Run `validate-loop` to check pre-launch readiness, including mailbox, gateway, notifier, memory, harness, state, run artifacts, workspace, and launchability posture.
5. Run `launch-agents` to launch prepared agents without beginning loop work.
6. Run `start` to send the first planning trigger after required agents are live.

## Workspace Posture

`prepare-workspace` should use the standard in-repo Git worktree layout through `houmao-utils-workspace-mgr`. The task root is `houmao-ws/lead-code-synth-research/`; each `lcsr-*` agent gets a private `repo/` Git worktree on branch `houmao/lead-code-synth-research/<agent-name>/main` plus an agent-local `states/` directory. The task also uses `shared-kb/`, `owner-states/<run-id>/`, and workspace-manager docs at `houmao-ws/workspaces.md` and `houmao-ws/lead-code-synth-research/workspace.md`.

Agents launch from the repo root. The parent checkout is the shared visibility surface and is read-only by default for source edits; source mutation belongs in the owning agent's private `repo/` worktree.

## CLI Tool Posture

Use both available CLI tools. Planned Codex CLI agents are `lcsr-cuda-coder-1`, `lcsr-cuda-coder-2`, `lcsr-synthesizer`, and `lcsr-researcher`, using Houmao project credential `codex-pro`. Planned Claude CLI agents are `lcsr-planner` and `lcsr-evaluator`, using Houmao project credential `claude-kimi-cred`.

The generated execplan records credential display names and posture only. It does not store subscription tokens or API keys.

## Privileged Profiling

NCU may require sudo for privileged counters on local machines. Agents that invoke NCU should read the sudo password from the runtime environment variable `NCU_ROOT_PW` only when sudo is required. Do not store the `NCU_ROOT_PW` value in Houmao profile defaults, mail, state, logs, run artifacts, or generated execplan files.

## Control Posture

The default run state is `not_started`, the default execution mode is `auto`, and notifier prompts are the normal wakeup path in auto mode. Manual mode is not pause; it suspends or disables loop notifier wakeups and lets the operator prompt one bounded participant turn.

Supported operator actions are `stop`, `pause`, `resume`, `redirect`, `invalidate`, `force-new-cycle`, `mode-switch`, and `recover`. The loop has no automatic completion state, so human operator stop is the terminal authority.

## Evaluation Posture

Planner owns current-best writes only after accepted Evaluator evidence from `official-timing`. Local checks, profiler evidence, and synthesis reports are exploratory or contextual unless they are later accepted through the Evaluator path.

CUDA Coders must stay within the candidate source or variant edit surface. Benchmark harness edits, dataset edits, reference implementation edits, semantic contest config edits, hidden answer caches, and sample-specific shortcuts are forbidden.

## Blocker Posture

Agents pick a spare local GPU dynamically. If no spare GPU is available, the agent records a waiting-for-GPU state and sends a `gpu-wait-report` to Planner for later wakeup. Non-GPU blockers are retried up to three times, then reported to Planner through `failure-report`.
