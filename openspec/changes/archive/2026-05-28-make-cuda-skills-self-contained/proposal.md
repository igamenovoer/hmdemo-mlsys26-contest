## Why

CUDA domain skills currently reference a local `kbs/cuda-kernel-optimization-kb/...` tree that is not present inside the skill directories. This makes the skills non-portable and pushes agents toward a large external knowledge base instead of compact, task-focused guidance.

## What Changes

- Rewrite CUDA skill reference pages that point at `kbs/cuda-kernel-optimization-kb/...` so they embed the essential decision guidance directly in the skill.
- Replace local KB path anchors with concise source-basis sections and online references to public papers, repositories, documentation, or project pages.
- Keep the skills small by extracting only workflow-relevant facts, guardrails, applicability signals, and validation cues rather than copying the KB wiki, raw source captures, PDFs, logs, or outputs.
- Verify the CUDA skill tree no longer references missing local `kbs/` paths.

## Capabilities

### New Capabilities

- `domain-skill-self-containment`: Defines portability requirements for external domain skills that are tracked by this project.

### Modified Capabilities

- None.

## Impact

- Affects the `extern/tracked/domain-skills` submodule content, specifically CUDA skills under `domain/cuda/`.
- The parent repository will need to record the updated submodule pointer after the domain-skills changes are committed upstream or locally in the submodule.
- No runtime contest code, Pixi commands, benchmark scripts, or project CLI behavior changes.
