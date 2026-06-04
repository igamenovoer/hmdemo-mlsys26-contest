from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from hmdemo_mlsys26_contest.terminal_record import service as terminal_record_service
from hmdemo_mlsys26_contest.terminal_record.models import (
    DEFAULT_SAMPLE_INTERVAL_SECONDS,
    TERMINAL_RECORD_SCHEMA_VERSION,
    TerminalRecordLabel,
    TerminalRecordLabels,
    TerminalRecordLiveState,
    TerminalRecordManifest,
    TerminalRecordPaths,
    TerminalRecordTarget,
    load_labels,
    load_live_state,
    load_manifest,
    now_utc_iso,
    save_live_state,
    save_manifest,
)
from hmdemo_mlsys26_contest.terminal_record.service import (
    TerminalRecordController,
    TerminalRecordError,
    _build_recorder_shell_command,
    add_terminal_record_label,
    parse_asciinema_cast_input_events,
    resolve_terminal_record_target,
    start_terminal_record,
    status_terminal_record,
    stop_terminal_record,
)
from hmdemo_mlsys26_contest.terminal_record.tmux_runtime import (
    TmuxCommandError,
    TmuxPaneRecord,
)


def _target() -> TerminalRecordTarget:
    return TerminalRecordTarget(
        session_name="contest-session",
        pane_id="%1",
        window_id="@2",
        window_name="agent",
    )


def _manifest(
    *,
    run_root: Path,
    mode: str = "active",
    tool: str | None = "codex",
    input_capture_level: str | None = None,
) -> TerminalRecordManifest:
    capture_level = input_capture_level or (
        "authoritative_managed" if mode == "active" else "output_only"
    )
    return TerminalRecordManifest(
        schema_version=TERMINAL_RECORD_SCHEMA_VERSION,
        run_id=run_root.name,
        mode=mode,
        repo_root=str(run_root.parent),
        run_root=str(run_root),
        target=_target(),
        tool=tool,
        sample_interval_seconds=DEFAULT_SAMPLE_INTERVAL_SECONDS,
        visual_recording_kind=("interactive_client" if mode == "active" else "readonly_observer"),
        input_capture_level=capture_level,
        run_tainted=False,
        taint_reasons=(),
        recorder_session_name=f"HMREC-{run_root.name}",
        attach_command=(
            f"env -u TMUX tmux attach-session -t HMREC-{run_root.name}"
            if mode == "active"
            else None
        ),
        started_at_utc="2026-03-19T00:00:00+00:00",
        stopped_at_utc=None,
        stop_reason=None,
    )


def _live_state(
    *, run_root: Path, mode: str = "active", status: str = "running"
) -> TerminalRecordLiveState:
    paths = TerminalRecordPaths.from_run_root(run_root=run_root)
    return TerminalRecordLiveState(
        schema_version=TERMINAL_RECORD_SCHEMA_VERSION,
        run_id=run_root.name,
        mode=mode,
        status=status,
        repo_root=str(run_root.parent),
        run_root=str(run_root),
        manifest_path=str(paths.manifest_path),
        controller_pid=None,
        target_session_name="contest-session",
        target_pane_id="%1",
        stop_requested_at_utc=None,
        last_error=None,
        updated_at_utc=now_utc_iso(),
    )


def _write_run_artifacts(
    *,
    run_root: Path,
    mode: str = "active",
    status: str = "running",
    tool: str | None = "codex",
) -> TerminalRecordPaths:
    paths = TerminalRecordPaths.from_run_root(run_root=run_root)
    save_manifest(paths.manifest_path, _manifest(run_root=run_root, mode=mode, tool=tool))
    save_live_state(paths.live_state_path, _live_state(run_root=run_root, mode=mode, status=status))
    return paths


def _read_ndjson(path: Path) -> list[dict[str, object]]:
    return [
        json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()
    ]


def test_resolve_terminal_record_target_rejects_ambiguous_sessions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        terminal_record_service,
        "has_tmux_session",
        lambda *, session_name: subprocess.CompletedProcess(
            args=["tmux", "has-session", "-t", session_name],
            returncode=0,
            stdout="",
            stderr="",
        ),
    )
    monkeypatch.setattr(
        terminal_record_service,
        "resolve_tmux_pane_shared",
        lambda *, session_name, pane_id: (_ for _ in ()).throw(
            TmuxCommandError(
                f"Ambiguous tmux pane target for `{session_name}`: 2 panes matched; "
                "provide pane_id, window_id, window_index, or window_name."
            )
        ),
    )

    with pytest.raises(TerminalRecordError, match="multiple panes; provide --target-pane"):
        resolve_terminal_record_target(target_session="contest-session", target_pane=None)


def test_resolve_terminal_record_target_accepts_explicit_pane(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        terminal_record_service,
        "has_tmux_session",
        lambda *, session_name: subprocess.CompletedProcess(
            args=["tmux", "has-session", "-t", session_name],
            returncode=0,
            stdout="",
            stderr="",
        ),
    )
    monkeypatch.setattr(
        terminal_record_service,
        "resolve_tmux_pane_shared",
        lambda *, session_name, pane_id: TmuxPaneRecord(
            pane_id=pane_id or "%9",
            session_name=session_name,
            window_id="@9",
            window_index="2",
            window_name="agent",
            pane_index="0",
            pane_active=False,
            pane_dead=False,
            pane_pid=4242,
        ),
    )

    target = resolve_terminal_record_target(target_session="contest-session", target_pane="%9")

    assert target == TerminalRecordTarget(
        session_name="contest-session",
        pane_id="%9",
        window_id="@9",
        window_name="agent",
    )


def test_start_terminal_record_persists_manifest_and_attach_command(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run-001"
    observed: dict[str, object] = {}

    class _DummyProcess:
        def __init__(self) -> None:
            self.pid = 4321

    def _fake_wait(live_state_path: Path) -> None:
        state = load_live_state(live_state_path)
        save_live_state(
            live_state_path,
            TerminalRecordLiveState(
                schema_version=state.schema_version,
                run_id=state.run_id,
                mode=state.mode,
                status="running",
                repo_root=state.repo_root,
                run_root=state.run_root,
                manifest_path=state.manifest_path,
                controller_pid=4321,
                target_session_name=state.target_session_name,
                target_pane_id=state.target_pane_id,
                stop_requested_at_utc=state.stop_requested_at_utc,
                last_error=None,
                updated_at_utc=now_utc_iso(),
            ),
        )

    def _fake_popen(
        cmd: list[str],
        *,
        cwd: Path,
        stdout: object,
        stderr: int,
        start_new_session: bool,
        text: bool,
    ) -> _DummyProcess:
        observed["cmd"] = cmd
        observed["cwd"] = cwd
        observed["stdout_name"] = getattr(stdout, "name", None)
        observed["stderr"] = stderr
        observed["start_new_session"] = start_new_session
        observed["text"] = text
        return _DummyProcess()

    monkeypatch.setattr(terminal_record_service, "ensure_tmux_available", lambda: None)
    monkeypatch.setattr(terminal_record_service, "_repo_root", lambda: tmp_path)
    monkeypatch.setattr(
        terminal_record_service,
        "resolve_terminal_record_target",
        lambda *, target_session, target_pane: _target(),
    )
    monkeypatch.setattr(terminal_record_service, "_wait_for_controller", _fake_wait)
    monkeypatch.setattr(subprocess, "Popen", _fake_popen)

    result = start_terminal_record(
        mode="active",
        target_session="contest-session",
        target_pane=None,
        tool="codex",
        run_root=run_root,
        sample_interval_seconds=0.1,
    )

    manifest = load_manifest(run_root / "manifest.json")

    assert result["status"] == "running"
    assert result["run_root"] == str(run_root.resolve())
    assert result["attach_command"] == f"env -u TMUX tmux attach-session -t HMREC-{run_root.name}"
    assert manifest.input_capture_level == "authoritative_managed"
    assert manifest.visual_recording_kind == "interactive_client"
    assert observed["cwd"] == tmp_path
    assert observed["stdout_name"] == str((run_root / "controller.log").resolve())
    assert observed["cmd"] == [
        os.sys.executable,
        "-m",
        "hmdemo_mlsys26_contest.terminal_record.cli",
        "_controller-run",
        "--live-state-path",
        str((run_root / "live_state.json").resolve()),
    ]


def test_status_terminal_record_reports_controller_liveness(tmp_path: Path) -> None:
    run_root = tmp_path / "run-002"
    paths = _write_run_artifacts(run_root=run_root, mode="passive", status="running")
    state = load_live_state(paths.live_state_path)
    save_live_state(
        paths.live_state_path,
        TerminalRecordLiveState(
            schema_version=state.schema_version,
            run_id=state.run_id,
            mode=state.mode,
            status=state.status,
            repo_root=state.repo_root,
            run_root=state.run_root,
            manifest_path=state.manifest_path,
            controller_pid=os.getpid(),
            target_session_name=state.target_session_name,
            target_pane_id=state.target_pane_id,
            stop_requested_at_utc=state.stop_requested_at_utc,
            last_error=state.last_error,
            updated_at_utc=state.updated_at_utc,
        ),
    )

    status = status_terminal_record(run_root=run_root)

    assert status["status"] == "running"
    assert status["controller_alive"] is True
    assert status["mode"] == "passive"
    assert status["input_capture_level"] == "output_only"


def test_stop_terminal_record_requests_orderly_shutdown(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run-003"
    paths = _write_run_artifacts(run_root=run_root, mode="active", status="running")

    def _fake_wait(live_state_path: Path) -> None:
        current = load_live_state(live_state_path)
        assert current.stop_requested_at_utc is not None
        save_live_state(
            live_state_path,
            TerminalRecordLiveState(
                schema_version=current.schema_version,
                run_id=current.run_id,
                mode=current.mode,
                status="stopped",
                repo_root=current.repo_root,
                run_root=current.run_root,
                manifest_path=current.manifest_path,
                controller_pid=current.controller_pid,
                target_session_name=current.target_session_name,
                target_pane_id=current.target_pane_id,
                stop_requested_at_utc=current.stop_requested_at_utc,
                last_error=None,
                updated_at_utc=now_utc_iso(),
            ),
        )
        manifest = load_manifest(paths.manifest_path)
        save_manifest(
            paths.manifest_path,
            TerminalRecordManifest(
                schema_version=manifest.schema_version,
                run_id=manifest.run_id,
                mode=manifest.mode,
                repo_root=manifest.repo_root,
                run_root=manifest.run_root,
                target=manifest.target,
                tool=manifest.tool,
                sample_interval_seconds=manifest.sample_interval_seconds,
                visual_recording_kind=manifest.visual_recording_kind,
                input_capture_level=manifest.input_capture_level,
                run_tainted=manifest.run_tainted,
                taint_reasons=manifest.taint_reasons,
                recorder_session_name=manifest.recorder_session_name,
                attach_command=manifest.attach_command,
                started_at_utc=manifest.started_at_utc,
                stopped_at_utc=now_utc_iso(),
                stop_reason="stop_requested",
            ),
        )

    monkeypatch.setattr(terminal_record_service, "_wait_for_final_status", _fake_wait)

    result = stop_terminal_record(run_root=run_root)

    assert result["status"] == "stopped"
    assert result["stop_reason"] == "stop_requested"
    assert result["run_root"] == str(run_root.resolve())


def test_build_recorder_shell_command_changes_by_mode(tmp_path: Path) -> None:
    active_manifest = _manifest(run_root=tmp_path / "active-run", mode="active")
    passive_manifest = _manifest(run_root=tmp_path / "passive-run", mode="passive")

    active_command = _build_recorder_shell_command(active_manifest)
    passive_command = _build_recorder_shell_command(passive_manifest)

    assert "pixi run asciinema rec" in active_command
    assert "--stdin" in active_command
    assert "attach-session -d -t contest-session" in active_command
    assert "select-pane -t %1" in active_command
    assert "asciinema.log" in active_command

    assert "pixi run asciinema rec" in passive_command
    assert "--stdin" not in passive_command
    assert "attach-session -r -t contest-session" in passive_command


def test_capture_snapshot_appends_incrementing_samples(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run-004"
    paths = _write_run_artifacts(run_root=run_root, mode="active", status="running")
    controller = TerminalRecordController(live_state_path=paths.live_state_path)
    outputs = iter(["first frame", "second frame"])

    monkeypatch.setattr(
        terminal_record_service,
        "capture_tmux_pane",
        lambda *, target: next(outputs),
    )

    controller._capture_snapshot()
    controller._capture_snapshot()

    snapshots = _read_ndjson(paths.pane_snapshots_path)
    assert [item["sample_id"] for item in snapshots] == ["s000001", "s000002"]
    assert [item["output_text"] for item in snapshots] == ["first frame", "second frame"]


def test_taint_run_degrades_active_capture_level(tmp_path: Path) -> None:
    run_root = tmp_path / "run-006"
    paths = _write_run_artifacts(run_root=run_root, mode="active", status="running")
    controller = TerminalRecordController(live_state_path=paths.live_state_path)

    controller._taint_run("multiple_clients_attached")

    manifest = load_manifest(paths.manifest_path)
    assert manifest.run_tainted is True
    assert manifest.input_capture_level == "managed_only"
    assert manifest.taint_reasons == ("multiple_clients_attached",)


def test_parse_asciinema_cast_input_events_reads_input_frames(tmp_path: Path) -> None:
    cast_path = tmp_path / "session.cast"
    cast_path.write_text(
        "\n".join(
            [
                '{"version": 2, "width": 120, "height": 40, "timestamp": 1710000000}',
                '[0.125, "o", "frame"]',
                '[0.5, "i", "/model"]',
                '[0.75, "i", "\\r"]',
                '[1.0, "x", 0]',
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    events = parse_asciinema_cast_input_events(
        cast_path=cast_path,
        started_at_utc="2026-03-19T00:00:00+00:00",
    )

    assert [item.source for item in events] == ["asciinema_input", "asciinema_input"]
    assert [item.sequence for item in events] == ["/model", "\r"]
    assert [item.event_id for item in events] == ["i000001", "i000002"]


def test_add_terminal_record_label_writes_exportable_structured_labels(tmp_path: Path) -> None:
    run_root = tmp_path / "run-008"
    output_dir = tmp_path / "exported-fixture"
    run_root.mkdir(parents=True, exist_ok=True)

    first = add_terminal_record_label(
        run_root=run_root,
        output_dir=output_dir,
        label_id="approval-state",
        sample_id="s000021",
        sample_end_id=None,
        scenario_id="approval-recovery",
        expectations={
            "business_state": "awaiting_operator",
            "turn_phase": "unknown",
        },
        note="Operator approval requested",
    )
    second = add_terminal_record_label(
        run_root=run_root,
        output_dir=output_dir,
        label_id="approval-state",
        sample_id="s000021",
        sample_end_id="s000025",
        scenario_id="approval-recovery",
        expectations={
            "business_state": "awaiting_operator",
            "last_turn_source": "none",
        },
        note=None,
    )

    labels = load_labels(output_dir / "labels.json")

    assert first["label_count"] == 1
    assert second["label_count"] == 1
    assert labels == TerminalRecordLabels(
        schema_version=TERMINAL_RECORD_SCHEMA_VERSION,
        labels=(
            TerminalRecordLabel(
                label_id="approval-state",
                scenario_id="approval-recovery",
                sample_id="s000021",
                sample_end_id="s000025",
                expectations={
                    "business_state": "awaiting_operator",
                    "last_turn_source": "none",
                },
                note=None,
            ),
        ),
    )
