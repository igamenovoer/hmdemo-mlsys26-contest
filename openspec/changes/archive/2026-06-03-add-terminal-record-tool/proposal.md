## Why

The project needs a repo-local way to record tmux sessions while agents work on kernel variants, without depending on the Houmao checkout being present on the machine. Copying the recorder into this repository makes debugging and sharing terminal traces repeatable from the project Pixi environment.

## What Changes

- Add a project-local terminal recorder package derived from Houmao's tmux recording tool.
- Expose the recorder through a `terminal-record` console script that supports starting, checking, stopping, and labeling recorder runs.
- Store recording artifacts under `tmp/terminal_record/` by default so generated output stays out of Git.
- Document the Pixi invocation and the artifact contract.
- Add the external recorder runtime dependency needed to produce asciicast files.

## Capabilities

### New Capabilities
- `terminal-record-tool`: Project-local tmux terminal recording commands and artifact layout.

### Modified Capabilities

None.

## Impact

Affected areas include `src/hmdemo_mlsys26_contest/terminal_record/`, `pyproject.toml`, `pixi.lock`, docs, and focused unit tests. The tool uses the local `tmux` executable and the Pixi-provided `asciinema` command at runtime; default unit tests do not require a live tmux server or CUDA.
