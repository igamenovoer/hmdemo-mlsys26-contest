## ADDED Requirements

### Requirement: Domain skills are self-contained
Tracked domain skills SHALL be usable from their skill directory without depending on ignored orphan checkouts, local knowledge-base paths, or missing `kbs/` directories.

#### Scenario: CUDA skills contain no local KB dependency
- **WHEN** the CUDA domain skill tree is searched for `kbs/cuda-kernel-optimization-kb`
- **THEN** no matches are found.

#### Scenario: No vendored KB directory is required
- **WHEN** a CUDA domain skill is opened from `domain/cuda/`
- **THEN** the skill does not require a sibling or nested `kbs/` directory to follow its workflow or references.

### Requirement: External knowledge is distilled into compact guidance
When a skill uses external knowledge to guide decisions, the skill SHALL embed the essential guidance in compact, skill-native form rather than requiring readers to open a copied knowledge-base wiki.

#### Scenario: Source-derived guidance is actionable
- **WHEN** a reference page incorporates knowledge from the CUDA optimization KB
- **THEN** the page states the applicable workload or hardware regime.
- **AND** the page states the optimization idea or workflow decision it supports.
- **AND** the page states constraints, failure modes, or guardrails.
- **AND** the page states validation signals such as measurements, counters, correctness checks, or workload shapes.

### Requirement: Online source provenance is retained
Skill reference pages that distill external knowledge SHALL include online provenance for deeper reading whenever stable public source material is available.

#### Scenario: Public source material is available
- **WHEN** a distilled source card is based on a public paper, repository, official document, or project documentation page
- **THEN** the card includes a source reference that can be resolved online.

#### Scenario: Public source material is unavailable
- **WHEN** a distilled source card is based only on local source-mining notes or unavailable material
- **THEN** the card explicitly labels that basis instead of presenting a local KB path as a usable reference.

### Requirement: Bulk KB material is excluded
The implementation SHALL NOT vendor the CUDA optimization KB wiki, raw source captures, PDFs, logs, outputs, or ignored orphan checkout into the skill directories.

#### Scenario: Skill directories remain compact
- **WHEN** the affected skill directories are inspected after the rewrite
- **THEN** they contain rewritten skill and reference content.
- **AND** they do not contain copied KB `raw/`, `outputs/`, `log/`, or full `wiki/` trees.
