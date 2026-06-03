#!/usr/bin/env python3
"""Generated loop-local helper for lead-code-synth-research."""

from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

try:
    import click
    from jinja2 import Template
except ImportError as exc:
    print(
        "Missing harness dependency: "
        f"{exc.name}. Install it into the active harness Python environment "
        "or use the Python environment associated with the installed Houmao uv tool. "
        "Inspect uv tool environments with: uv tool list --show-paths --show-python",
        file=sys.stderr,
    )
    raise

try:
    import jsonschema
except ImportError:
    jsonschema = None


ROOT = Path(__file__).resolve().parents[1]
EXECPLAN = ROOT.parent


def _json(path: Path) -> dict:
    return json.loads(path.read_text())


@click.group()
def cli() -> None:
    """Loop-local validation, email, and control helpers."""


@cli.command("validate-package")
def validate_package() -> None:
    required = [
        EXECPLAN / "manifest.toml",
        EXECPLAN / "specs/collab/collab-overview.md",
        EXECPLAN / "specs/objective/objective.toml",
        EXECPLAN / "specs/comms/templates.toml",
        EXECPLAN / "specs/state/schema.sql",
        EXECPLAN / "agents/bindings.toml",
    ]
    missing = [str(path.relative_to(EXECPLAN)) for path in required if not path.exists()]
    click.echo(json.dumps({"ok": not missing, "missing": missing}, indent=2))
    if missing:
        raise SystemExit(1)


@cli.group()
def email() -> None:
    """Email schema, validation, and rendering helpers."""


@email.command("schema")
@click.argument("family")
def email_schema(family: str) -> None:
    path = EXECPLAN / "specs/comms/schemas" / f"{family}.schema.json"
    click.echo(path.relative_to(EXECPLAN))
    if not path.exists():
        raise SystemExit(1)


@email.command("validate")
@click.argument("family")
@click.argument("payload_path", type=click.Path(exists=True, path_type=Path))
def email_validate(family: str, payload_path: Path) -> None:
    if jsonschema is None:
        print(
            "Missing harness dependency: jsonschema. Install it into the active "
            "harness Python environment or use the Python environment associated "
            "with the installed Houmao uv tool. Inspect uv tool environments with: "
            "uv tool list --show-paths --show-python",
            file=sys.stderr,
        )
        raise SystemExit(1)
    schema = _json(EXECPLAN / "specs/comms/schemas" / f"{family}.schema.json")
    payload = _json(payload_path)
    jsonschema.validate(payload, schema)
    click.echo(json.dumps({"ok": True, "family": family}, indent=2))


@email.command("render")
@click.argument("family")
@click.argument("payload_path", type=click.Path(exists=True, path_type=Path))
def email_render(family: str, payload_path: Path) -> None:
    payload = _json(payload_path)
    template_path = EXECPLAN / "specs/comms/renderers" / f"{family}.md.j2"
    click.echo(Template(template_path.read_text()).render(**payload))


@cli.group()
def control() -> None:
    """Control-state helpers."""


@control.command("status")
@click.option("--db", type=click.Path(path_type=Path), required=True)
@click.option("--run-id", required=True)
def control_status(db: Path, run_id: str) -> None:
    with sqlite3.connect(db) as conn:
        row = conn.execute(
            "SELECT run_state, execution_mode, terminal_reason FROM runs WHERE run_id = ?",
            (run_id,),
        ).fetchone()
    click.echo(json.dumps({"run_id": run_id, "state": row}, indent=2))


@control.command("set-mode")
@click.option("--db", type=click.Path(path_type=Path), required=True)
@click.option("--run-id", required=True)
@click.option("--mode", type=click.Choice(["auto", "manual"]), required=True)
def control_set_mode(db: Path, run_id: str, mode: str) -> None:
    with sqlite3.connect(db) as conn:
        conn.execute("UPDATE runs SET execution_mode = ? WHERE run_id = ?", (mode, run_id))
        conn.commit()
    click.echo(json.dumps({"run_id": run_id, "execution_mode": mode}, indent=2))


@cli.command("manual-context")
@click.option("--participant", required=True)
@click.option("--run-id", required=True)
def manual_context(participant: str, run_id: str) -> None:
    click.echo(
        json.dumps(
            {
                "run_id": run_id,
                "participant": participant,
                "mode": "manual",
                "allowed_action": "process one relevant mail event or perform one tick pass, then stop",
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    cli()
