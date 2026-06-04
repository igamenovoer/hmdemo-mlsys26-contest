---
name: project-dev-tmux-record
description: Use this project skill when Codex needs to record, inspect, stop, label, convert, or explain tmux recordings in this repository, including repository-local `terminal-record` runs and all-pane tmux window captures. Trigger for requests about tmux session recording, terminal traces, asciinema captures, `pane_snapshots.ndjson`, `window_snapshots.ndjson`, `input_events.ndjson`, debugging agent terminal sessions, or documenting how to use this repo's recorder.
---

# Project Dev Tmux Record

Use the repository-local recorder through Pixi for single-pane or active/input-aware captures. For tmux sessions with multiple panes, record every visible pane with the bundled all-pane window sampler instead of selecting one pane.

## Quick Flow

1. Confirm the target tmux session and pane count:

```bash
tmux ls
tmux list-panes -t SESSION -F '#{pane_id} #{pane_index} #{pane_width}x#{pane_height} title=#{pane_title} active=#{pane_active}'
```

2. If the target session has more than one visible pane, record all panes:

```bash
python skillset/dev/project-dev-tmux-record/scripts/tmux_window_record.py start \
  --target-session SESSION \
  --sample-interval-seconds 0.2
```

3. Use `terminal-record` passive mode for observation-only captures of a single-pane session:

```bash
pixi run terminal-record start --mode passive --target-session SESSION --sample-interval-seconds 0.2
```

4. Use active mode only when stdin/input capture matters. Active mode is single-pane/session-attach oriented; if the target has multiple panes and screen fidelity matters, run the all-pane sampler alongside the active recorder:

```bash
pixi run terminal-record start --mode active --target-session SESSION --tool codex --sample-interval-seconds 0.2
```

5. Pass `--target-pane` only when the user explicitly asks for one pane, or when the session has multiple panes but the intended artifact is that pane alone:

```bash
pixi run terminal-record start --mode passive --target-session SESSION --target-pane %1 --sample-interval-seconds 0.2
```

6. Save the printed `run_root`. Use the matching status and stop command for the recorder type:

```bash
pixi run terminal-record status --run-root tmp/terminal_record/RUN_ID
pixi run terminal-record stop --run-root tmp/terminal_record/RUN_ID
python skillset/dev/project-dev-tmux-record/scripts/tmux_window_record.py status --run-root tmp/tmux-recording/RUN_ID-window
python skillset/dev/project-dev-tmux-record/scripts/tmux_window_record.py stop --run-root tmp/tmux-recording/RUN_ID-window
```

Always stop recorder runs you start before ending the task unless the user explicitly asks to keep recording.

## Multiple Panes

When a tmux session has multiple panes, do not record only the active pane and call it a session recording. Use `scripts/tmux_window_record.py` to write `window_snapshots.ndjson`, where each sample contains the tmux window layout plus every pane's id, title, coordinates, size, active flag, and `capture-pane -ep` output.

The all-pane sampler writes ignored run roots under `tmp/tmux-recording/<timestamp>-<session>-window/` by default. Use its `manifest.json`, `live_state.json`, and `window_snapshots.ndjson` for inspection and rendering. If a later MP4 is needed, render from `window_snapshots.ndjson` so the video preserves the original pane geometry.

## Frame Rate

Default to normal mode: `--sample-interval-seconds 0.2`, which records snapshots at 5 samples per second. This controls `pane_snapshots.ndjson` or `window_snapshots.ndjson`, not asciinema playback FPS; `session.cast` remains event/timing based.

- `low`: 2 fps, `--sample-interval-seconds 0.5`. Use for long recordings where coarse state changes are enough.
- `normal`: 5 fps, `--sample-interval-seconds 0.2`. Use by default.
- `high`: 20 fps, `--sample-interval-seconds 0.05`. Use for short recordings where rapid UI changes matter.

Only change from normal mode when the user asks for low/high recording or the recording length makes file size/overhead more important than smooth trace detail.

## Mode Guidance

- `passive`: Read-only observer. Use by default for debugging an agent session, capturing output, or collecting pane snapshots without changing the operator's attach path.
- `active`: Recorder-owned interactive attach path with asciinema stdin capture. Use when the exact typed input stream is part of the evidence. Extra tmux clients attached to the target can taint active capture, so mention taint reasons from `status` if present.

## Artifacts

Each `terminal-record` run root contains stable paths:

- `manifest.json`: target, mode, capture level, taint metadata, recorder session, and timing.
- `live_state.json`: controller status used by `status` and `stop`.
- `session.cast`: asciinema recording for human playback.
- `pane_snapshots.ndjson`: periodic `tmux capture-pane` samples; use this as the main machine-readable trace.
- `input_events.ndjson`: stdin events from active mode and any managed input events.
- `labels.json`: labels added with `add-label`.
- `controller.log` and `asciinema.log`: failure/debug logs.

When diagnosing a recording, start with `manifest.json`, `live_state.json`, and the tail of `pane_snapshots.ndjson`. Read logs only when start/stop/status reports failure.

Each all-pane window-sampler run root contains:

- `manifest.json`: target session, timing, recorder kind, and sample count after stop.
- `live_state.json`: controller status used by `status` and `stop`.
- `window_snapshots.ndjson`: periodic full-window samples with all visible panes and coordinates.
- `controller.log`: controller stdout/stderr and failure details.

When diagnosing a multi-pane recording, first verify a recent sample has the expected pane count and layout:

```bash
python - <<'PY'
import json
from pathlib import Path
run_root = Path("tmp/tmux-recording/RUN_ID-window")
last = json.loads(run_root.joinpath("window_snapshots.ndjson").read_text(encoding="utf-8").splitlines()[-1])
print(last["layout"])
print([(p["title"], p["pane_id"], p["left"], p["top"], p["width"], p["height"]) for p in last["panes"]])
PY
```

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
python skillset/dev/project-dev-tmux-record/scripts/tmux_window_record.py --help
pixi run pytest tests/unit/terminal_record/test_service.py
pixi run ruff check src/hmdemo_mlsys26_contest/terminal_record tests/unit/terminal_record
pixi run mypy src/hmdemo_mlsys26_contest/terminal_record
openspec validate terminal-record-tool
```

For deeper user-facing command details, read `docs/reference/terminal-record/index.md`.
