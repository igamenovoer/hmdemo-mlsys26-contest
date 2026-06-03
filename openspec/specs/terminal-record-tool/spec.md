# terminal-record-tool Specification

## Purpose
TBD - created by archiving change add-terminal-record-tool. Update Purpose after archive.
## Requirements
### Requirement: Recorder Command Availability
The project SHALL provide a `terminal-record` command in the Pixi environment for tmux recording operations.

#### Scenario: Command help is available
- **WHEN** a user runs `pixi run terminal-record --help`
- **THEN** the command prints recorder usage and exits successfully.

### Requirement: Recorder Run Lifecycle
The recorder SHALL support starting, inspecting, and stopping a run against an existing tmux session.

#### Scenario: Start records run metadata
- **WHEN** a user starts a recorder run with a target session and optional target pane
- **THEN** the tool creates a run root containing manifest and live-state files that identify the tmux target, recorder mode, controller process, and artifact paths.

#### Scenario: Stop requests graceful shutdown
- **WHEN** a user stops a running recorder by run root
- **THEN** the tool records the stop request in live state and returns the finalized run status when the controller stops or fails.

### Requirement: Recorder Artifacts
The recorder SHALL store generated recording artifacts under `tmp/terminal_record/` by default and SHALL keep each run self-describing.

#### Scenario: Default run root
- **WHEN** a user starts a run without `--run-root`
- **THEN** the tool creates a timestamped run directory below `tmp/terminal_record/`.

#### Scenario: Artifact layout
- **WHEN** a run is active or finalized
- **THEN** the run root contains stable paths for `manifest.json`, `live_state.json`, `session.cast`, `pane_snapshots.ndjson`, `input_events.ndjson`, `labels.json`, `controller.log`, and `asciinema.log`.

### Requirement: Label Capture
The recorder SHALL allow users to persist structured labels for recorded samples or sample ranges.

#### Scenario: Add or replace label
- **WHEN** a user adds a label with an existing label id
- **THEN** the tool replaces the old label with the new label while preserving other labels.

