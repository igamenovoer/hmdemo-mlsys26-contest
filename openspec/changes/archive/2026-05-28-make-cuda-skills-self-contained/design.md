## Context

The `extern/tracked/domain-skills` submodule now contains CUDA optimization skills under `domain/cuda/`. Two of those skills still contain local knowledge-base anchors:

- `krnopt-cuda-domain-optimization`: MoE domain reference pages cite 38 unique `kbs/cuda-kernel-optimization-kb/...` paths.
- `krnopt-hw-aware-optimization`: Hopper MoE and hardware-utilization references cite 20 unique `kbs/cuda-kernel-optimization-kb/...` paths.

There are 50 unique referenced KB pages in total. The copied orphan KB exists at `extern/tracked/domain-skills/extern/orphan/cuda-kernel-optimization-kb`, but `extern/orphan` is ignored and is not a portable skill dependency. Copying the whole curated wiki into the skills would be about 2.6 MB, and copying raw materials would be much larger. The skill should instead carry compact domain guidance, with online provenance for deeper reading.

## Goals / Non-Goals

**Goals:**

- Make every CUDA skill usable without a local `kbs/` directory or ignored orphan checkout.
- Preserve the decision-useful content from the referenced KB pages inside the relevant skill reference files.
- Keep extracted content compact and agent-oriented: applicability, workflow cues, constraints, failure modes, validation signals, and source lineage.
- Replace local KB anchors with online references where a reader can follow up for papers, repositories, official docs, or project documentation.
- Verify the CUDA skill tree has no remaining `kbs/cuda-kernel-optimization-kb` references after implementation.

**Non-Goals:**

- Do not vendor the KB wiki, raw PDFs, raw source captures, logs, outputs, or ignored orphan checkout into skill directories.
- Do not rewrite unrelated CUDA skills that have no external KB references.
- Do not change contest solution code, Pixi commands, project CLI behavior, benchmark scripts, or runtime dependencies.
- Do not claim source-reported speedups as local performance facts.

## Decisions

### Distill KB material into compact skill-native source cards

For each reference page that currently lists local KB anchors, replace those anchors with one or more compact cards. Each card should capture:

- when the idea applies
- the kernel or workflow boundary it affects
- the concrete design signal an agent should look for
- constraints and failure modes
- validation counters, workloads, or correctness checks
- online source references for deeper reading

This keeps the skills small and directly usable while still preserving the original research lineage.

Alternative considered: copy the directly referenced 50 KB pages. This fixes broken paths but leaves many internal wiki links dangling and still makes the skill depend on the KB's wiki structure.

Alternative considered: copy the whole KB wiki. This is complete enough for links but too broad for a focused skill and encourages agents to browse a miniature wiki instead of following the skill workflow.

### Rewrite only the affected skill references

Implementation should focus on files containing `kbs/cuda-kernel-optimization-kb` under:

- `domain/cuda/krnopt-cuda-domain-optimization/references/`
- `domain/cuda/krnopt-hw-aware-optimization/references/`

Unrelated skills should remain untouched unless a verification pass finds another local KB dependency.

### Preserve source lineage as online provenance, not local paths

The compact cards should include public source references such as:

- paper identifiers or official paper pages
- GitHub repositories for source-backed implementations
- NVIDIA or project documentation links
- public project docs for serving/runtime backend policies

When the orphan KB only has a local note as its source, the implementation should extract the public upstream material named by that note when available. If no reliable online reference exists, the card should mark the source as internal/source-mined context and avoid presenting it as a public link.

### Verification is text-based

This change is documentation and skill-content work. Verification should use repository search and lightweight inspection:

- no `kbs/cuda-kernel-optimization-kb` references remain in `domain/cuda`
- no new `kbs/` directory is added under affected skills
- affected pages contain embedded guidance rather than only source lists
- affected pages include online references or explicit notes when no public online source is available

## Risks / Trade-offs

- Distillation can omit nuance from the KB -> keep cards structured and preserve links to online source material for deep dives.
- Online references can become stale -> prefer stable identifiers such as arXiv IDs, official docs, and canonical repository URLs.
- Rewriting source anchors could make future KB sync harder -> treat the KB as research input, not a runtime dependency, and keep source-card headings aligned with the original technique names.
- The submodule may need its own commit before the parent pointer can be meaningful -> verify both the submodule status and the parent repository status after implementation.

## Migration Plan

1. Inventory all `kbs/cuda-kernel-optimization-kb` references in `domain/cuda`.
2. For each affected reference page, read the corresponding KB summaries/concepts from the orphan checkout and extract compact source cards.
3. Replace local KB anchor lists with embedded guidance and online provenance.
4. Run verification searches for local KB references and accidental vendored `kbs/` directories.
5. Review submodule changes, then update the parent repository's submodule pointer as appropriate.

Rollback is straightforward: revert the submodule edits and parent pointer update.

## Open Questions

- Some KB summaries are based on local source-mining notes rather than direct public pages. During implementation, decide case-by-case whether the online reference should be a repository, paper, official docs page, or a brief note that no stable public reference was identified.
