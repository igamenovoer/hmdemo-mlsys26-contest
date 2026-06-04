# Terminal Recorder

The terminal recorder captures an already-running tmux session for later review. It is a project-local port of Houmao's tmux recording tool, trimmed to avoid Houmao runtime and parser dependencies.

Run it from the repository root with Pixi:

```bash
pixi run terminal-record start --mode passive --target-session SESSION
```

Use `active` mode when you want asciinema to record stdin as well as terminal output:

```bash
pixi run terminal-record start --mode active --target-session SESSION --tool codex
```

If the session has more than one pane, pass the explicit pane id:

```bash
pixi run terminal-record start --mode passive --target-session SESSION --target-pane %1
```

Inspect and stop a run with the run root printed by `start`:

```bash
pixi run terminal-record status --run-root tmp/terminal_record/20260603-120000-SESSION
pixi run terminal-record stop --run-root tmp/terminal_record/20260603-120000-SESSION
```

Add a structured label for a recorded sample:

```bash
pixi run terminal-record add-label \
  --run-root tmp/terminal_record/20260603-120000-SESSION \
  --label-id interesting-state \
  --sample-id s000021 \
  --note "Prompt reached approval state"
```

## Artifacts

Each run writes a self-contained directory below `tmp/terminal_record/` unless `--run-root` is set. Important files include:

- `manifest.json`: target session, pane, mode, capture level, taint state, recorder tmux session, and timing metadata.
- `live_state.json`: controller status used by `status` and `stop`.
- `session.cast`: asciinema recording for human review.
- `pane_snapshots.ndjson`: periodic `tmux capture-pane` samples.
- `input_events.ndjson`: stdin events parsed from `session.cast` in active mode and any future managed-input events.
- `labels.json`: structured labels added with `add-label`.
- `controller.log` and `asciinema.log`: runtime logs for debugging.

The tool requires host `tmux` and records through the Pixi-provided `asciinema` command.
