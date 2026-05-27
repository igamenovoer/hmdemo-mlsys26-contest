## Why

The repository now has a `skillset/` tree for project-local agent skills, but its intended audience split is not documented in the project contract. Making the boundary explicit prevents development-maintenance skills from being confused with CUDA kernel optimization runtime skills.

## What Changes

- Document `skillset/` as the home for skills used by this project.
- Define `skillset/dev/` as developer-facing skills for maintaining and evolving the project itself.
- Define `skillset/runtime/` as skills for agents that optimize CUDA kernels, either automatically or with human assistance.
- Add lightweight in-tree README files so each directory carries its purpose even when browsed outside `AGENTS.md`.
- No contest solution code, benchmark behavior, pack format, Pixi commands, or CUDA kernel implementation changes.

## Capabilities

### New Capabilities

- `project-skillset-layout`: Defines the project-local skill directory layout and the intended audience boundary between development skills and runtime CUDA optimization skills.

### Modified Capabilities

- None.

## Impact

- Affects repository documentation and placeholder files under `skillset/`.
- Affects agent/developer conventions only; no Python package, CLI, runtime dependency, generated solution artifact, or benchmark workflow is changed.
