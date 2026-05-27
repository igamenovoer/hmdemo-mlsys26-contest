## ADDED Requirements

### Requirement: Project Skillset Directory

The repository SHALL document `skillset/` as the project-local home for skills used by this project.

#### Scenario: Agent discovers project-local skills

- **WHEN** an agent reads the repository layout documentation
- **THEN** it can identify `skillset/` as the location for project-local skills

### Requirement: Development Skill Boundary

The repository SHALL document `skillset/dev/` as the location for developer-facing skills used to maintain, evolve, or operate this project, not for CUDA kernel optimization workflows.

#### Scenario: Developer adds a maintenance skill

- **WHEN** a developer adds a skill for project setup, workflow maintenance, documentation upkeep, testing, packaging, or repository operations
- **THEN** the documented destination is `skillset/dev/`

### Requirement: Runtime CUDA Optimization Skill Boundary

The repository SHALL document `skillset/runtime/` as the location for skills used by agents to optimize CUDA kernels, whether the optimization is automatic or human-assisted.

#### Scenario: Agent adds a CUDA optimization skill

- **WHEN** an agent or developer adds a skill whose purpose is CUDA kernel optimization for contest workloads
- **THEN** the documented destination is `skillset/runtime/`
