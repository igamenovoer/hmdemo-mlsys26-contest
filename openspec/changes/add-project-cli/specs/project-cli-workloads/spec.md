## ADDED Requirements

### Requirement: Project CLI exposes workload commands
The system SHALL expose a `project-cli workload` command group for managing workload sources, workload records, and workload sets.

#### Scenario: Workload command group is available
- **WHEN** a user runs `project-cli workload --help`
- **THEN** the CLI lists `source`, `list`, `show`, and `set` subcommands.

### Requirement: Workload configuration is tracked
The system SHALL store shared workload source and workload set configuration in `configs/workloads.toml`.

#### Scenario: Workload source list reads tracked config
- **WHEN** a user runs `project-cli workload source list`
- **THEN** the CLI reads sources from `configs/workloads.toml` and prints their names, kinds, and paths.

### Requirement: Dataset-root workload sources are supported
The system SHALL support workload sources of kind `dataset-root` that point to a contest dataset root containing workload JSONL files.

#### Scenario: Register dataset-root source
- **WHEN** a user runs `project-cli workload source register contest-local --kind dataset-root --path extern/orphan/mlsys26-contest`
- **THEN** the CLI records the source in `configs/workloads.toml`.

### Requirement: Workload-dir sources are supported
The system SHALL support workload sources of kind `workload-dir` that pair a dataset root with an alternate workload JSONL directory.

#### Scenario: Register workload-dir source
- **WHEN** a user runs `project-cli workload source register moe-smoke --kind workload-dir --dataset-root extern/orphan/mlsys26-contest --workload-dir tmp/workloads/moe-smoke`
- **THEN** the CLI records the source in `configs/workloads.toml`.

### Requirement: Workloads can be listed from a source
The system SHALL list workload records for a selected source and exact definition.

#### Scenario: List workloads with limit
- **WHEN** a user runs `project-cli workload list --source contest-local --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 --limit 5`
- **THEN** the CLI prints at most five workload records from the matching workload JSONL.

### Requirement: Workloads can be shown by UUID prefix
The system SHALL show one workload record by exact UUID or unique UUID prefix.

#### Scenario: Show workload by unique prefix
- **WHEN** a user runs `project-cli workload show 2e69caee --source contest-local --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`
- **THEN** the CLI prints the matching workload record.

### Requirement: Ambiguous workload prefixes are rejected
The system SHALL reject workload selectors that match multiple workload UUIDs.

#### Scenario: Ambiguous prefix fails
- **WHEN** a user runs `project-cli workload show 2 --source contest-local --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` and multiple workloads match `2`
- **THEN** the CLI fails and reports that the selector is ambiguous.

### Requirement: Workload sets are registered with exact UUIDs
The system SHALL register named workload sets by resolving workload selectors to exact UUIDs before writing `configs/workloads.toml`.

#### Scenario: Register workload set from prefixes
- **WHEN** a user runs `project-cli workload set register moe-minimal --source contest-local --definition moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 --workload 2e69caee --workload 4822167c`
- **THEN** the CLI records exact workload UUIDs in `configs/workloads.toml`.

### Requirement: Workload sets can be inspected and removed
The system SHALL support listing, showing, and removing named workload sets.

#### Scenario: Remove workload set
- **WHEN** a user runs `project-cli workload set remove moe-minimal`
- **THEN** the CLI removes `moe-minimal` from `configs/workloads.toml`.
