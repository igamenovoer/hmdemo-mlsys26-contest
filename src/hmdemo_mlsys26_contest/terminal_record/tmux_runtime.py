"""Small tmux helpers used by the terminal recorder."""

from __future__ import annotations

import shutil
import subprocess
from collections.abc import Mapping
from dataclasses import dataclass


class TmuxCommandError(RuntimeError):
    """Raised when a tmux command cannot be executed reliably."""


@dataclass(frozen=True)
class TmuxPaneRecord:
    """One tmux pane record resolved from `list-panes` output."""

    pane_id: str
    session_name: str
    window_id: str
    window_index: str
    window_name: str
    pane_index: str
    pane_active: bool
    pane_dead: bool = False
    pane_pid: int | None = None


def ensure_tmux_available() -> None:
    """Fail fast when tmux is not available on PATH."""

    if shutil.which("tmux") is None:
        raise TmuxCommandError("`tmux` was not found on PATH.")


def has_tmux_session(*, session_name: str) -> subprocess.CompletedProcess[str]:
    """Return raw tmux `has-session` command output."""

    return run_tmux(["has-session", "-t", session_name])


def set_tmux_session_environment(*, session_name: str, env_vars: Mapping[str, str]) -> None:
    """Set multiple tmux session environment variables."""

    for key, value in env_vars.items():
        result = run_tmux(["set-environment", "-t", session_name, key, value])
        if result.returncode == 0:
            continue
        detail = tmux_error_detail(result)
        raise TmuxCommandError(
            f"Failed to set tmux environment variable `{key}` in session "
            f"`{session_name}`: {detail or 'unknown tmux error'}"
        )


def unset_tmux_session_environment(*, session_name: str, variable_names: list[str]) -> None:
    """Unset multiple tmux session environment variables."""

    for variable_name in variable_names:
        result = run_tmux(["set-environment", "-t", session_name, "-u", variable_name])
        if result.returncode == 0:
            continue
        detail = tmux_error_detail(result)
        raise TmuxCommandError(
            f"Failed to unset tmux environment variable `{variable_name}` in session "
            f"`{session_name}`: {detail or 'unknown tmux error'}"
        )


def read_tmux_session_environment_value(*, session_name: str, variable_name: str) -> str | None:
    """Return one optional tmux session environment value."""

    result = run_tmux(["show-environment", "-t", session_name, variable_name])
    if result.returncode != 0:
        detail = tmux_error_detail(result).lower()
        if "unknown variable" in detail or "unknown-environment" in detail:
            return None
        raise TmuxCommandError(
            f"Failed to read tmux environment variable `{variable_name}` from "
            f"`{session_name}`: {tmux_error_detail(result) or 'unknown tmux error'}"
        )

    line = (result.stdout or "").strip()
    if not line or line.startswith("-"):
        return None
    expected_prefix = f"{variable_name}="
    if not line.startswith(expected_prefix):
        raise TmuxCommandError(
            f"Unexpected tmux environment output for `{variable_name}` in `{session_name}`: {line}"
        )
    value = line[len(expected_prefix) :].strip()
    return value or None


def list_tmux_clients(*, session_name: str) -> tuple[str, ...]:
    """Return attached tmux client identifiers for one session."""

    result = run_tmux(["list-clients", "-t", session_name, "-F", "#{client_tty}"])
    if result.returncode != 0:
        detail = tmux_error_detail(result).lower()
        if "no current client" in detail or "no server running" in detail:
            return ()
        raise TmuxCommandError(
            f"Failed to list tmux clients for `{session_name}`: "
            f"{tmux_error_detail(result) or 'unknown tmux error'}"
        )
    return tuple(line.strip() for line in result.stdout.splitlines() if line.strip())


def list_tmux_panes(*, session_name: str) -> tuple[TmuxPaneRecord, ...]:
    """Return pane records for all panes in one tmux session."""

    format_parts = (
        "#{pane_id}",
        "#{session_name}",
        "#{window_id}",
        "#{window_index}",
        "#{window_name}",
        "#{pane_index}",
        "#{pane_active}",
        "#{pane_dead}",
        "#{pane_pid}",
    )
    result = run_tmux(["list-panes", "-a", "-t", session_name, "-F", "\t".join(format_parts)])
    if result.returncode != 0:
        detail = tmux_error_detail(result)
        raise TmuxCommandError(
            f"Failed to list tmux panes for `{session_name}`: {detail or 'unknown tmux error'}"
        )
    panes: list[TmuxPaneRecord] = []
    for line in result.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) != len(format_parts):
            raise TmuxCommandError(f"Unexpected tmux pane output for `{session_name}`: {line}")
        pane_pid = int(fields[8]) if fields[8].isdigit() else None
        panes.append(
            TmuxPaneRecord(
                pane_id=fields[0],
                session_name=fields[1],
                window_id=fields[2],
                window_index=fields[3],
                window_name=fields[4],
                pane_index=fields[5],
                pane_active=fields[6] == "1",
                pane_dead=fields[7] == "1",
                pane_pid=pane_pid,
            )
        )
    return tuple(panes)


def resolve_tmux_pane(*, session_name: str, pane_id: str | None = None) -> TmuxPaneRecord:
    """Resolve one tmux pane by optional pane id."""

    panes = list_tmux_panes(session_name=session_name)
    if not panes:
        raise TmuxCommandError(f"No tmux panes are available for `{session_name}`.")

    if pane_id is not None:
        matching = tuple(pane for pane in panes if pane.pane_id == pane_id)
        if not matching:
            raise TmuxCommandError(
                f"No tmux panes matched pane id `{pane_id}` in `{session_name}`."
            )
        return _prefer_live_tmux_pane(matching)

    if len(panes) != 1:
        raise TmuxCommandError(
            f"Ambiguous tmux pane target for `{session_name}`: {len(panes)} panes matched; "
            "provide pane_id, window_id, window_index, or window_name."
        )
    return _prefer_live_tmux_pane(panes)


def capture_tmux_pane(*, target: str) -> str:
    """Return capture-pane text for one tmux target."""

    result = run_tmux(["capture-pane", "-p", "-e", "-S", "-", "-t", target])
    if result.returncode != 0:
        detail = tmux_error_detail(result)
        raise TmuxCommandError(
            f"Failed to capture tmux pane `{target}`: {detail or 'unknown tmux error'}"
        )
    return result.stdout.rstrip("\n")


def kill_tmux_session(*, session_name: str) -> None:
    """Kill a tmux session."""

    result = run_tmux(["kill-session", "-t", session_name])
    if result.returncode == 0:
        return
    detail = tmux_error_detail(result)
    raise TmuxCommandError(
        f"Failed to kill tmux session `{session_name}`: {detail or 'unknown tmux error'}"
    )


def run_tmux(
    args: list[str], *, timeout_seconds: float | None = None
) -> subprocess.CompletedProcess[str]:
    """Run a tmux command with normalized invocation behavior."""

    try:
        return subprocess.run(
            ["tmux", *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
    except OSError as exc:
        raise TmuxCommandError(f"Failed to run tmux command `{args}`: {exc}") from exc
    except subprocess.TimeoutExpired as exc:
        raise TmuxCommandError(f"Timed out running tmux command `{args}`") from exc


def tmux_error_detail(result: subprocess.CompletedProcess[str]) -> str:
    """Extract concise stderr/stdout detail from a tmux command result."""

    return (result.stderr or result.stdout or "").strip()


def _prefer_live_tmux_pane(panes: tuple[TmuxPaneRecord, ...]) -> TmuxPaneRecord:
    """Prefer a live pane when tmux reports multiple matching panes."""

    live = tuple(pane for pane in panes if not pane.pane_dead)
    if live:
        active = tuple(pane for pane in live if pane.pane_active)
        return active[0] if active else live[0]
    return panes[0]
