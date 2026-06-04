## 1. Package and CLI

- [x] 1.1 Add the project-local `hmdemo_mlsys26_contest.terminal_record` package.
- [x] 1.2 Add a `terminal-record` console script and Pixi/asciinema dependency support.
- [x] 1.3 Document common recorder commands and artifacts.

## 2. Recorder Runtime

- [x] 2.1 Port the recorder models and persistence helpers.
- [x] 2.2 Implement local tmux helper functions without Houmao runtime imports.
- [x] 2.3 Adapt start, status, stop, capture, and label flows to the local package path.

## 3. Verification

- [x] 3.1 Add focused unit tests for target resolution, command construction, lifecycle state, snapshots, input parsing, and labels.
- [x] 3.2 Run OpenSpec validation and project tests or targeted tests.
