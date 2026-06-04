---
name: project-dev-tmux-record
description: Use this project skill when Codex needs to record, inspect, stop, label, or explain recordings from the repository-local `terminal-record` tmux recorder. Trigger for requests about tmux session recording, terminal traces, asciinema captures, `pane_snapshots.ndjson`, `input_events.ndjson`, debugging agent terminal sessions, or documenting how to use this repo's recorder.
---

# Project Dev Tmux Record

Use the repository-local recorder through Pixi. The recorder captures an already-running tmux session and writes self-contained artifacts under ignored `tmp/terminal_record/` directories by default.

## Quick Flow

1. Confirm the target tmux session and pane:

```bash
tmux ls
tmux list-panes -t SESSION -F '#{pane_id} #{window_name} active=#{pane_active}'
```

2. Prefer passive mode for observation-only captures:

```bash
pixi run terminal-record start --mode passive --target-session SESSION --sample-interval-seconds 0.2
```

3. Use active mode only when stdin/input capture matters. After `start`, use the printed `attach_command` to interact through the recorder-owned tmux session:

```bash
pixi run terminal-record start --mode active --target-session SESSION --tool codex --sample-interval-seconds 0.2
```

4. If the target session has multiple panes, pass the pane id:

```bash
pixi run terminal-record start --mode passive --target-session SESSION --target-pane %1 --sample-interval-seconds 0.2
```

5. Save the printed `run_root`. Use it for status and stop:

```bash
pixi run terminal-record status --run-root tmp/terminal_record/RUN_ID
pixi run terminal-record stop --run-root tmp/terminal_record/RUN_ID
```

Always stop recorder runs you start before ending the task unless the user explicitly asks to keep recording.

## Frame Rate

Default to normal mode: `--sample-interval-seconds 0.2`, which records `pane_snapshots.ndjson` at 5 samples per second. This controls the tmux pane snapshot rate, not asciinema playback FPS; `session.cast` remains event/timing based.

- `low`: 2 fps, `--sample-interval-seconds 0.5`. Use for long recordings where coarse state changes are enough.
- `normal`: 5 fps, `--sample-interval-seconds 0.2`. Use by default.
- `high`: 20 fps, `--sample-interval-seconds 0.05`. Use for short recordings where rapid UI changes matter.

Only change from normal mode when the user asks for low/high recording or the recording length makes file size/overhead more important than smooth trace detail.

## Mode Guidance

- `passive`: Read-only observer. Use by default for debugging an agent session, capturing output, or collecting pane snapshots without changing the operator's attach path.
- `active`: Recorder-owned interactive attach path with asciinema stdin capture. Use when the exact typed input stream is part of the evidence. Extra tmux clients attached to the target can taint active capture, so mention taint reasons from `status` if present.

## Artifacts

Each run root contains stable paths:

- `manifest.json`: target, mode, capture level, taint metadata, recorder session, and timing.
- `live_state.json`: controller status used by `status` and `stop`.
- `session.cast`: asciinema recording for human playback.
- `pane_snapshots.ndjson`: periodic `tmux capture-pane` samples; use this as the main machine-readable trace.
- `input_events.ndjson`: stdin events from active mode and any managed input events.
- `labels.json`: labels added with `add-label`.
- `controller.log` and `asciinema.log`: failure/debug logs.

When diagnosing a recording, start with `manifest.json`, `live_state.json`, and the tail of `pane_snapshots.ndjson`. Read logs only when start/stop/status reports failure.

## Labels

Use labels when the user wants to mark a checkpoint or sample range:

```bash
pixi run terminal-record add-label \
  --run-root tmp/terminal_record/RUN_ID \
  --label-id descriptive-id \
  --sample-id s000021 \
  --sample-end-id s000025 \
  --note "Why this state matters"
```

Reusing a `label-id` replaces that label while preserving other labels.

## Checks

Use these checks when changing or validating the recorder:

```bash
pixi run terminal-record --help
pixi run pytest tests/unit/terminal_record/test_service.py
pixi run ruff check src/hmdemo_mlsys26_contest/terminal_record tests/unit/terminal_record
pixi run mypy src/hmdemo_mlsys26_contest/terminal_record
openspec validate terminal-record-tool
```

For deeper user-facing command details, read `docs/reference/terminal-record/index.md`.
