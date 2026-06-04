#!/usr/bin/env python3
"""Record every visible pane in one tmux window as periodic snapshots."""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    start = subparsers.add_parser("start")
    start.add_argument("--target-session", required=True)
    start.add_argument("--run-root")
    start.add_argument("--sample-interval-seconds", type=float, default=0.2)

    stop = subparsers.add_parser("stop")
    stop.add_argument("--run-root", required=True)

    status = subparsers.add_parser("status")
    status.add_argument("--run-root", required=True)

    controller = subparsers.add_parser("run-controller")
    controller.add_argument("--target-session", required=True)
    controller.add_argument("--run-root", required=True)
    controller.add_argument("--sample-interval-seconds", type=float, required=True)

    args = parser.parse_args(argv)
    if args.command == "start":
        return start_recording(args)
    if args.command == "stop":
        return stop_recording(Path(args.run_root))
    if args.command == "status":
        return print_status(Path(args.run_root))
    if args.command == "run-controller":
        return run_controller(
            target_session=args.target_session,
            run_root=Path(args.run_root),
            sample_interval_seconds=args.sample_interval_seconds,
        )
    raise AssertionError(args.command)


def start_recording(args: argparse.Namespace) -> int:
    run_root = Path(args.run_root) if args.run_root else default_run_root(args.target_session)
    run_root = run_root.resolve()
    run_root.mkdir(parents=True, exist_ok=True)
    controller_log = run_root / "controller.log"
    command = [
        sys.executable,
        str(Path(__file__).resolve()),
        "run-controller",
        "--target-session",
        args.target_session,
        "--run-root",
        str(run_root),
        "--sample-interval-seconds",
        str(args.sample_interval_seconds),
    ]
    with controller_log.open("ab") as log:
        process = subprocess.Popen(
            command,
            stdout=log,
            stderr=log,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    state_path = run_root / "live_state.json"
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if state_path.exists():
            payload = read_json(state_path)
            if payload.get("status") == "running":
                print_json(
                    {
                        "status": "running",
                        "controller_pid": process.pid,
                        "run_root": str(run_root),
                        "target_session": args.target_session,
                        "sample_interval_seconds": args.sample_interval_seconds,
                    }
                )
                return 0
        if process.poll() is not None:
            break
        time.sleep(0.1)
    print(f"error: controller did not start; see {controller_log}", file=sys.stderr)
    return 2


def stop_recording(run_root: Path) -> int:
    run_root = run_root.resolve()
    state = read_json(run_root / "live_state.json")
    (run_root / "STOP").write_text("stop requested\n", encoding="utf-8")
    pid = int(state.get("pid", 0) or 0)
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        status = read_json(run_root / "live_state.json")
        if status.get("status") in {"stopped", "error"}:
            print_json(status)
            return 0 if status.get("status") == "stopped" else 2
        time.sleep(0.2)
    print_json(read_json(run_root / "live_state.json") | {"stop_wait": "timed_out"})
    return 2


def print_status(run_root: Path) -> int:
    run_root = run_root.resolve()
    status = read_json(run_root / "live_state.json")
    snapshots_path = run_root / "window_snapshots.ndjson"
    status["snapshot_count"] = count_lines(snapshots_path) if snapshots_path.exists() else 0
    status["run_root_size_bytes"] = sum(
        path.stat().st_size for path in run_root.rglob("*") if path.is_file()
    )
    print_json(status)
    return 0


def run_controller(
    *,
    target_session: str,
    run_root: Path,
    sample_interval_seconds: float,
) -> int:
    run_root = run_root.resolve()
    run_root.mkdir(parents=True, exist_ok=True)
    started = datetime.now(timezone.utc)
    manifest_path = run_root / "manifest.json"
    state_path = run_root / "live_state.json"
    snapshots_path = run_root / "window_snapshots.ndjson"
    stop_path = run_root / "STOP"
    running = True

    def handle_stop(_signum: int, _frame: Any) -> None:
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "recording_kind": "tmux_window_snapshot",
        "target_session": target_session,
        "sample_interval_seconds": sample_interval_seconds,
        "started_at_utc": utc_now(started),
        "run_root": str(run_root),
        "pid": os.getpid(),
    }
    write_json(manifest_path, manifest)
    write_state(
        state_path,
        status="running",
        target_session=target_session,
        run_root=run_root,
        started_at_utc=manifest["started_at_utc"],
        sample_interval_seconds=sample_interval_seconds,
    )
    sample_count = 0
    try:
        while running and not stop_path.exists():
            now = datetime.now(timezone.utc)
            layout = tmux(
                [
                    "display-message",
                    "-p",
                    "-t",
                    target_session,
                    "#{window_width} #{window_height} #{window_layout}",
                ]
            ).rstrip("\n")
            panes = capture_panes(target_session)
            sample_count += 1
            payload = {
                "sample_id": f"s{sample_count:06d}",
                "ts_utc": utc_now(now),
                "elapsed_seconds": (now - started).total_seconds(),
                "layout": layout,
                "panes": panes,
            }
            with snapshots_path.open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(payload, ensure_ascii=False) + "\n")
            if sample_count % 10 == 0:
                write_state(
                    state_path,
                    status="running",
                    target_session=target_session,
                    run_root=run_root,
                    started_at_utc=manifest["started_at_utc"],
                    sample_interval_seconds=sample_interval_seconds,
                    sample_count=sample_count,
                )
            time.sleep(sample_interval_seconds)
        stop_reason = "stop_file" if stop_path.exists() else "signal"
        stopped_at = utc_now()
        manifest["stopped_at_utc"] = stopped_at
        manifest["stop_reason"] = stop_reason
        manifest["samples"] = sample_count
        write_json(manifest_path, manifest)
        write_state(
            state_path,
            status="stopped",
            target_session=target_session,
            run_root=run_root,
            started_at_utc=manifest["started_at_utc"],
            sample_interval_seconds=sample_interval_seconds,
            sample_count=sample_count,
            stop_reason=stop_reason,
            stopped_at_utc=stopped_at,
        )
        return 0
    except Exception as exc:
        write_state(
            state_path,
            status="error",
            target_session=target_session,
            run_root=run_root,
            started_at_utc=manifest["started_at_utc"],
            sample_interval_seconds=sample_interval_seconds,
            sample_count=sample_count,
            stop_reason=repr(exc),
        )
        raise


def capture_panes(target_session: str) -> list[dict[str, Any]]:
    pane_rows = tmux(
        [
            "list-panes",
            "-t",
            target_session,
            "-F",
            "#{pane_id}\t#{pane_index}\t#{pane_left}\t#{pane_top}\t#{pane_width}\t#{pane_height}\t#{pane_title}\t#{pane_active}",
        ]
    ).splitlines()
    panes: list[dict[str, Any]] = []
    for row in pane_rows:
        pane_id, pane_index, left, top, width, height, title, active = row.split("\t", 7)
        panes.append(
            {
                "pane_id": pane_id,
                "pane_index": int(pane_index),
                "left": int(left),
                "top": int(top),
                "width": int(width),
                "height": int(height),
                "title": title,
                "active": active == "1",
                "output_text": tmux(["capture-pane", "-ep", "-t", pane_id]),
            }
        )
    return panes


def write_state(
    path: Path,
    *,
    status: str,
    target_session: str,
    run_root: Path,
    started_at_utc: str,
    sample_interval_seconds: float,
    sample_count: int | None = None,
    stop_reason: str | None = None,
    stopped_at_utc: str | None = None,
) -> None:
    payload: dict[str, Any] = {
        "status": status,
        "pid": os.getpid(),
        "target_session": target_session,
        "sample_interval_seconds": sample_interval_seconds,
        "started_at_utc": started_at_utc,
        "updated_at_utc": utc_now(),
        "run_root": str(run_root),
    }
    if sample_count is not None:
        payload["sample_count"] = sample_count
    if stop_reason is not None:
        payload["stop_reason"] = stop_reason
    if stopped_at_utc is not None:
        payload["stopped_at_utc"] = stopped_at_utc
    write_json(path, payload)


def default_run_root(target_session: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    safe_session = target_session.replace("/", "-").replace(":", "-")
    return Path("tmp") / "tmux-recording" / f"{stamp}-{safe_session}-window"


def tmux(args: list[str]) -> str:
    result = subprocess.run(["tmux", *args], text=True, capture_output=True, check=True)
    return result.stdout


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def print_json(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8") as stream:
        return sum(1 for _ in stream)


def utc_now(value: datetime | None = None) -> str:
    return (value or datetime.now(timezone.utc)).isoformat().replace("+00:00", "Z")


if __name__ == "__main__":
    raise SystemExit(main())
