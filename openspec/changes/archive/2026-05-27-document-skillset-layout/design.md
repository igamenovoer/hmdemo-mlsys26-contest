## Context

The repository already contains `skillset/dev/` and `skillset/runtime/` placeholders, but the top-level layout documentation does not describe what belongs in either directory. Agents and human developers need a stable convention because project-development skills and CUDA optimization runtime skills serve different audiences and should be loaded in different contexts.

## Goals / Non-Goals

**Goals:**

- Make the `skillset/` tree discoverable from the main agent instructions.
- Keep the directory-level documentation short and local to each skill audience.
- Preserve the distinction between developer skills and CUDA kernel optimization skills.

**Non-Goals:**

- Do not define the full skill file format.
- Do not add or change any CUDA optimization strategy.
- Do not alter the contest solution, benchmark, pack, or project CLI behavior.

## Decisions

### Document the boundary in both global and local places

`AGENTS.md` should list `skillset/`, `skillset/dev/`, and `skillset/runtime/` in the layout section because it is the first contract agents see. Each directory should also have a README so the convention remains visible when browsing the tree directly.

Alternative considered: only document the split in `AGENTS.md`. That keeps fewer files, but the empty directories still lack local context for contributors adding skills.

### Keep the skillset tree lightweight

The implementation should add README files and retain placeholders only where needed for empty directories. It should not add generated indexes, registries, or automation until the project has actual skills that require them.

Alternative considered: create a manifest now. That would be premature because no local project skills have been added yet.

## Risks / Trade-offs

- Directory-level README files can drift from `AGENTS.md` -> keep all wording compact and aligned around the same audience split.
- Future runtime skills may include helper material for humans -> define runtime skills by purpose, CUDA kernel optimization, rather than by whether a human or an agent initiates them.
