# Artifact Index

This generated support view indexes the current execplan package for operator review. It is not authoritative; use the linked contracts, generated skills, generated bindings, and harness files for exact behavior.

## Package Areas

- `../manifest.toml`: package metadata for `cli-credential-assignment-stage-0002`, including stage status, CLI tool assignment, runtime skill assignment, workspace materialization, omissions, and validation notes.
- `../adrs/`: eight accepted decisions covering candidate handoff refs, Coder result routing, GPU wait routing, failure routing, synthesis routing, `lcsr-*` agent names, full `skillset/runtime/*` assignment, in-repo Git worktree workspace materialization, and CLI tool distribution.
- `../specs/objective/`: Fused MoE optimization objective, promotion gate, correctness policy, anti-hacking policy, retry policy, and resource policy.
- `../specs/participants/`: stable role and participant contracts for the human operator, Planner, two CUDA Coders, Synthesizer, Researcher, Evaluator, and Profiler tool surface.
- `../specs/collab/`: generic-loop process, result routing, cycle control, blocker handling, GPU waiting posture, and operator control posture.
- `../specs/collab/topology/`: machine-readable directed topology and predecessor-context contracts.
- `../specs/comms/`: ten TOML-to-schema-to-Markdown mail templates, JSON schemas, renderers, and notifier-prompt contracts.
- `../specs/state/`: sqlite schema, seed, invariants, and state overview for durable control-plane bookkeeping.
- `../specs/workspace/`: six isolated `lcsr-*` in-repo Git worktree workspaces and workspace validation inputs.
- `../specs/run/`: run artifact layout and run control contract.
- `../harness/`: generated CLI entrypoint, command registry, command-envelope schema, and Python harness source.
- `../skills/`: one flat generated skill package per shared, on-event, on-tick, and operator-control responsibility.
- `../agents/`: `bindings.toml`, six `lcsr-*` planned profile directories, memo seeds, definitions, and notifier prompt files.
- `./`: final support docs for artifact index, runtime model, operator guide, and validation posture.

## Runtime Skills

All six managed agents receive every directory under `../../../../skillset/runtime`, including symlinked `krnopt-*` entries treated as real skill directories: `krnopt-cuda-coding`, `krnopt-cuda-domain-optimization`, `krnopt-cuda-generic-optimization`, `krnopt-cuda-profiling`, `krnopt-cuda-structural-optimization`, `krnopt-hw-aware-optimization`, `krnopt-low-precision-kernel-formats`, `project-op-variant-comparison`, `project-op-variant-profiling`, and `project-op-variant-validation`.

The NCU sudo-password env name is `NCU_ROOT_PW`; only the env name is recorded here, never its value.

## CLI Tools

The planned CLI split uses Codex CLI with Houmao project credential `codex-pro` for `lcsr-cuda-coder-1`, `lcsr-cuda-coder-2`, `lcsr-synthesizer`, and `lcsr-researcher`, and Claude CLI with Houmao project credential `claude-kimi-cred` for `lcsr-planner` and `lcsr-evaluator`. Credential material stays outside generated execplan artifacts.

## Intentional Omissions

- Live Houmao profile creation, mailbox setup, gateway setup, notifier setup, memory updates, workspace creation, agent launch, and start trigger delivery are omitted from finalization and belong to later execution stages.
- GPU or dataset-dependent benchmark checks are omitted from default execplan validation and live under runtime evaluation flows.
- Per-profile local README files are omitted because `../agents/bindings.toml` and each profile `config.toml`, `definition.md`, and `memo-seed.md` provide the generated profile index.
- There is no automatic success condition; human operator stop is the terminal authority.
