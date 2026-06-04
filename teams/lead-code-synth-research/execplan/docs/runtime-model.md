# Runtime Model

This generated support view summarizes the runtime model for `lead-code-synth-research`. It is not authoritative; the exact contracts live under `../specs/`, generated skills live under `../skills/`, and concrete planned bindings live under `../agents/`.

## Loop Shape

The loop is a `generic-loop` for the Fused MoE workload `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`. Stable participants are the human operator, Planner, two parallel CUDA Coders, Synthesizer, Researcher, Evaluator, and a Profiler tool surface. Concrete live-facing agent ids use the `lcsr-*` prefix.

Planner starts planning cycles and assigns up to two Coder branches per cycle. CUDA Coders report normal candidate results to Synthesizer only. Synthesizer submits promotion candidates to Evaluator and sends Planner a context-only copy. Evaluator sends accepted or rejected promotion evidence to Planner, and only Planner writes current-best state after accepted `official-timing` evidence.

## Mail Runtime

The default runtime is notifier-prompt-driven. A Houmao mail notifier detects open mail, prompts the target agent, the agent dispatches by the in-body `schema_id`, runs the matching generated on-event skill, optionally runs the role tick skill, records required state or artifacts, sends or replies when required, and ends the chat turn.

The generated mail template registry is `../specs/comms/templates.toml`. Each outgoing message follows TOML payload, JSON Schema validation, Markdown rendering, and Houmao mail delivery. Rendered messages include parseable `houmao-email-metadata` near the top.

Generated schema ids cover `planning-cycle-start`, `optimization-assignment`, `coder-result`, `research-request`, `research-summary`, `synthesis-report`, `evaluation-report`, `failure-report`, `gpu-wait-report`, and `operator-intervention`.

## Tick Runtime

Generated on-tick skills do one bounded pass per prompt. They reconcile one open route or timeout, retry one eligible non-GPU blocker, retry one waiting-for-GPU item after wakeup, or apply one operator control. The loop does not depend on in-chat waiting, sleeps, polling loops, or periodic background tick workers.

## State and Artifacts

Generated state is sqlite control-plane bookkeeping for ids, refs, status, ownership, retry counters, evidence refs, operator events, and current-best history. Rich material such as source diffs, benchmark logs, rendered mail, profiler output, research notes, and official timing output belongs in mail, workspaces, or `../../runs/<run-id>/`.

Workspaces use standard in-repo Git worktrees under `houmao-ws/lead-code-synth-research/`. Each managed `lcsr-*` agent has a private `repo/` worktree and `states/` directory. Cross-run task knowledge uses `shared-kb/`; per-run owner bookkeeping uses `owner-states/<run-id>/`. Agents may read sibling worktrees and states by default, but source edits belong only in the owning agent's private worktree.

## Runtime Skills

Every managed `lcsr-*` agent is assigned the generated loop-local skills required by its role and all project runtime skills under `../../../../skillset/runtime/*`, including the symlinked `krnopt-*` directories. This lets Coders and supporting agents use CUDA coding, profiling, structural optimization, low-precision format, hardware-aware, domain optimization, variant comparison, variant profiling, and variant validation guidance from the same planned binding surface.

NCU profiling may require sudo for privileged counters. Agents read the sudo password only from runtime env `NCU_ROOT_PW` when such a profiler retry is necessary, and the value must not appear in mail, state, logs, artifacts, or profile defaults.

## CLI Runtime

Managed agents are intentionally split across two local CLI tools. Codex CLI with Houmao project credential `codex-pro` runs `lcsr-cuda-coder-1`, `lcsr-cuda-coder-2`, `lcsr-synthesizer`, and `lcsr-researcher`. Claude CLI with Houmao project credential `claude-kimi-cred` runs `lcsr-planner` and `lcsr-evaluator`. This keeps implementation, synthesis, and research on Codex while Planner and Evaluator use Claude/Kimi for independent planning and validation posture.

## Control Runtime

Auto mode uses notifier wakeups. Manual mode suspends or disables loop notifier wakeups and relies on operator-prompted bounded turns. `pause`, `resume`, `stop`, mode switch, redirect, invalidate, force-new-cycle, and recover actions are recorded through the generated control state and platform mechanics stay on maintained Houmao surfaces.
