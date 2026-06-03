## Context

Houmao already has a tmux terminal recorder, but its installed package imports Houmao runtime, parser, and managed-agent modules that do not exist in this contest starter kit. The contest project needs the recording workflow, not the full Houmao control plane.

## Goals / Non-Goals

**Goals:**

- Provide a local command that records an existing tmux session from the Pixi environment.
- Preserve the useful Houmao artifact shape: manifest, live state, pane snapshots, input events, labels, logs, and asciicast output.
- Keep generated recordings under ignored `tmp/` paths by default.
- Keep unit coverage independent of CUDA, live tmux, and a live asciinema process.

**Non-Goals:**

- Port Houmao managed-agent lifecycle integration.
- Port Houmao TUI parser analysis.
- Change contest kernel packaging or evaluation behavior.

## Decisions

- Vendor only the terminal recorder core under `hmdemo_mlsys26_contest.terminal_record`. The service, models, and CLI remain close to the Houmao source, while project-specific imports use local modules.
- Replace Houmao tmux helpers with a small subprocess-based tmux module. This keeps the dependency surface to `tmux` and avoids adding `libtmux`.
- Expose a `terminal-record` console script through `project.scripts`. Users can run `pixi run terminal-record ...` without remembering a Python module path.
- Add `asciinema` as a Python dependency so Pixi provides the `asciinema` command used by recording sessions.
- Keep `analyze` out of the local command surface for now because Houmao's analyzer depends on parser packages that are unrelated to this repository.

## Risks / Trade-offs

- Live recording still depends on host `tmux` being installed and on a target tmux session existing. The CLI fails early with a concrete error when `tmux` is missing or the target cannot be resolved.
- Input capture in active mode records asciinema input frames, but there is no project-local managed `send-keys` integration yet. The artifact model keeps `input_events.ndjson` compatible with future integration.
- The local tmux helper uses tmux formatted output instead of `libtmux`. Focused tests cover command construction and parsing, but end-to-end behavior still needs a machine with tmux and a terminal.
