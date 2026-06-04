from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import sqlite3
import sys
import tomllib
from typing import Any


def _missing_harness_dependency(package: str) -> SystemExit:
    message = f"""
Missing generated harness dependency: {package}

Options:
- install it into the Python environment running this harness
- run or retest with the Python environment associated with the installed Houmao uv tool

Helpful checks:
- uv tool list --show-paths --show-python
- uv tool install --force houmao
"""
    raise SystemExit(message.strip())


try:
    import click
except ModuleNotFoundError:
    raise _missing_harness_dependency("click")

try:
    from jinja2 import Environment, FileSystemLoader, StrictUndefined
except ModuleNotFoundError:
    raise _missing_harness_dependency("jinja2")

try:
    from jsonschema import Draft202012Validator
except ModuleNotFoundError:
    raise _missing_harness_dependency("jsonschema")


HARNESS_ROOT = Path(__file__).resolve().parents[1]
EXECPLAN_ROOT = HARNESS_ROOT.parent
LOOP_DIR = EXECPLAN_ROOT.parent
LOOP_SLUG = "lead-code-synth-research"
PLAN_REVISION = "harness-stage-0001"


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def rel_execplan(path: str) -> Path:
    return EXECPLAN_ROOT / path


def harness_relative(path: Path) -> str:
    if path.is_relative_to(EXECPLAN_ROOT):
        return str(Path("..") / path.relative_to(EXECPLAN_ROOT))
    return str(path)


def load_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as f:
        return tomllib.load(f)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def read_payload(path: Path) -> dict[str, Any]:
    if path.suffix == ".toml":
        return load_toml(path)
    if path.suffix == ".json":
        return load_json(path)
    raise click.ClickException(f"Unsupported payload extension for {path}; use .toml or .json")


def output(command: str, data: Any, *, run_id: str | None = None, diagnostics: list[str] | None = None, warnings: list[str] | None = None, success: bool = True) -> None:
    envelope = {
        "success": success,
        "command": command,
        "loop_slug": LOOP_SLUG,
        "run_id": run_id,
        "plan_revision": PLAN_REVISION,
        "data": data,
        "diagnostics": diagnostics or [],
        "warnings": warnings or [],
    }
    click.echo(json.dumps(envelope, indent=2, sort_keys=True))


def templates_registry() -> list[dict[str, Any]]:
    return load_toml(rel_execplan("specs/comms/templates.toml")).get("templates", [])


def resolve_template(name_or_schema: str) -> dict[str, Any]:
    for entry in templates_registry():
        if entry.get("name") == name_or_schema or entry.get("schema_id") == name_or_schema:
            return entry
    raise click.ClickException(f"Unknown template or schema_id: {name_or_schema}")


def schema_for_template(entry: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    path = rel_execplan("specs/comms") / entry["schema_path"]
    return path, load_json(path)


def validate_payload(entry: dict[str, Any], payload: dict[str, Any]) -> list[str]:
    _, schema = schema_for_template(entry)
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(payload), key=lambda e: list(e.path))
    return [f"{'/'.join(str(p) for p in e.path) or '<root>'}: {e.message}" for e in errors]


def db_connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def ensure_state_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(rel_execplan("specs/state/schema.sql").read_text())


def default_db(run_id: str) -> Path:
    return LOOP_DIR / "runs" / run_id / "state" / "loop.sqlite"


def open_existing_db(db: Path) -> sqlite3.Connection:
    if not db.exists():
        raise click.ClickException(f"State db does not exist: {db}")
    return db_connect(db)


def table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,)).fetchone()
    return row is not None


def rows(conn: sqlite3.Connection, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    return [dict(r) for r in conn.execute(query, params).fetchall()]


def explain_toml(path: Path) -> list[dict[str, Any]]:
    data = load_toml(path)
    out: list[dict[str, Any]] = []

    def walk(value: Any, key: str) -> None:
        if isinstance(value, dict):
            if "description" in value:
                out.append({"source_key": key, "description": value["description"]})
            for child_key, child_value in value.items():
                walk(child_value, f"{key}.{child_key}" if key else child_key)
        elif isinstance(value, list):
            for idx, item in enumerate(value):
                walk(item, f"{key}[{idx}]")

    walk(data, "")
    return out


@click.group()
def cli() -> None:
    """Generated loop-local harness for lead-code-synth-research."""


@cli.command("self-check")
def self_check() -> None:
    diagnostics: list[str] = []
    for path in [
        "manifest.toml",
        "specs/comms/templates.toml",
        "specs/collab/topology/topology.toml",
        "specs/collab/topology/context-posture.toml",
        "specs/state/schema.sql",
        "specs/workspace/workspace.toml",
    ]:
        target = rel_execplan(path)
        if not target.exists():
            raise click.ClickException(f"Missing referenced contract: {target}")
        diagnostics.append(f"found {path}")
    for entry in templates_registry():
        schema = rel_execplan("specs/comms") / entry["schema_path"]
        renderer = rel_execplan("specs/comms") / entry["renderer_path"]
        if not schema.exists() or not renderer.exists():
            raise click.ClickException(f"Template {entry['name']} has missing schema or renderer")
        schema_data = load_json(schema)
        if schema_data["properties"]["schema_id"]["const"] != entry["schema_id"]:
            raise click.ClickException(f"Template {entry['name']} schema_id mismatch")
    conn = sqlite3.connect(":memory:")
    conn.executescript(rel_execplan("specs/state/schema.sql").read_text())
    output("self-check", {"contracts": "ok", "templates": len(templates_registry()), "state_schema": "ok"}, diagnostics=diagnostics)


@cli.group()
def topology() -> None:
    """Topology validation and lookup."""


@topology.command("validate")
@click.option("--explain", is_flag=True)
def topology_validate(explain: bool) -> None:
    topo_path = rel_execplan("specs/collab/topology/topology.toml")
    topo = load_toml(topo_path)
    topology_data = topo["topology"]
    mode = topology_data["mode"]
    diagnostics = [f"mode={mode}"]
    aliases = {"generic-graph": "generic-loop", "generic graph": "generic-loop", "pairwise-tree": "tree-loop", "pairwise-loop": "tree-loop", "pairwise": "tree-loop"}
    normalized = aliases.get(mode, mode)
    if normalized not in {"generic-loop", "tree-loop"}:
        raise click.ClickException(f"Unsupported topology mode: {mode}")
    routes = topo.get("routes", [])
    if normalized == "generic-loop":
        cycle = topo.get("cycle_control", {})
        for key in ["cycle_id_required", "assignment_id_required", "candidate_id_required", "dedupe_keys"]:
            if key not in cycle:
                raise click.ClickException(f"generic-loop missing cycle_control.{key}")
        if not routes:
            raise click.ClickException("generic-loop requires explicit routes")
        diagnostics.append("generic-loop cycle posture explicit")
    data: dict[str, Any] = {"mode": mode, "normalized_mode": normalized, "routes": len(routes), "tool_routes": len(topo.get("tool_routes", []))}
    if explain:
        data["explain"] = explain_toml(topo_path)
    output("topology validate", data, diagnostics=diagnostics)


@topology.command("query")
@click.option("--route-id")
@click.option("--explain", is_flag=True)
def topology_query(route_id: str | None, explain: bool) -> None:
    topo_path = rel_execplan("specs/collab/topology/topology.toml")
    topo = load_toml(topo_path)
    routes = topo.get("routes", [])
    if route_id:
        routes = [r for r in routes if r["route_id"] == route_id]
    data: dict[str, Any] = {"topology": topo["topology"], "cycle_control": topo.get("cycle_control", {}), "routes": routes, "tool_routes": topo.get("tool_routes", [])}
    if explain:
        data["explain"] = explain_toml(topo_path)
    output("topology query", data)


@cli.group()
def context() -> None:
    """Predecessor context validation and lookup."""


@context.command("validate")
@click.option("--explain", is_flag=True)
def context_validate(explain: bool) -> None:
    path = rel_execplan("specs/collab/topology/context-posture.toml")
    data = load_toml(path)
    contexts = data.get("message_contexts", [])
    diagnostics = []
    for item in contexts:
        for key in ["message_family", "receiver", "carried_fields", "explicit_omission"]:
            if key not in item:
                raise click.ClickException(f"context entry missing {key}: {item}")
        diagnostics.append(f"{item['message_family']} -> {item['receiver']}")
    result: dict[str, Any] = {"message_contexts": len(contexts)}
    if explain:
        result["explain"] = explain_toml(path)
    output("context validate", result, diagnostics=diagnostics)


@context.command("query")
@click.option("--message-family")
@click.option("--explain", is_flag=True)
def context_query(message_family: str | None, explain: bool) -> None:
    path = rel_execplan("specs/collab/topology/context-posture.toml")
    data = load_toml(path)
    contexts = data.get("message_contexts", [])
    if message_family:
        contexts = [c for c in contexts if c["message_family"] == message_family]
    result: dict[str, Any] = {"message_contexts": contexts}
    if explain:
        result["explain"] = explain_toml(path)
    output("context query", result)


@cli.group()
def email() -> None:
    """Email schema, validation, rendering, and lifecycle helpers."""


@email.command("schema")
@click.argument("name_or_schema")
@click.option("--explain", is_flag=True)
def email_schema(name_or_schema: str, explain: bool) -> None:
    entry = resolve_template(name_or_schema)
    schema_path, schema = schema_for_template(entry)
    data: dict[str, Any] = {
        "template": entry,
        "schema_path": harness_relative(schema_path),
        "renderer_path": harness_relative(rel_execplan("specs/comms") / entry["renderer_path"]),
        "schema_title": schema.get("title"),
    }
    if explain:
        data["explain"] = [{"source_key": f"templates.{entry['name']}", "description": entry.get("description", "")}]
    output("email schema", data)


@email.command("validate")
@click.argument("name_or_schema")
@click.option("--payload", "payload_path", required=True, type=click.Path(path_type=Path))
def email_validate(name_or_schema: str, payload_path: Path) -> None:
    entry = resolve_template(name_or_schema)
    payload = read_payload(payload_path)
    errors = validate_payload(entry, payload)
    if errors:
        output("email validate", {"valid": False, "errors": errors}, run_id=payload.get("run_id"), success=False)
        raise SystemExit(1)
    output("email validate", {"valid": True, "schema_id": entry["schema_id"]}, run_id=payload.get("run_id"))


@email.command("render")
@click.argument("name_or_schema")
@click.option("--payload", "payload_path", required=True, type=click.Path(path_type=Path))
@click.option("--raw", is_flag=True, help="Print rendered Markdown without JSON envelope.")
def email_render(name_or_schema: str, payload_path: Path, raw: bool) -> None:
    entry = resolve_template(name_or_schema)
    payload = read_payload(payload_path)
    errors = validate_payload(entry, payload)
    if errors:
        output("email render", {"valid": False, "errors": errors}, run_id=payload.get("run_id"), success=False)
        raise SystemExit(1)
    renderer_path = rel_execplan("specs/comms") / entry["renderer_path"]
    env = Environment(loader=FileSystemLoader(str(renderer_path.parent)), undefined=StrictUndefined, autoescape=False)
    rendered = env.get_template(renderer_path.name).render(**payload)
    if "```houmao-email-metadata" not in rendered:
        raise click.ClickException("Renderer output is missing houmao-email-metadata block")
    if raw:
        click.echo(rendered)
    else:
        output("email render", {"schema_id": entry["schema_id"], "rendered": rendered}, run_id=payload.get("run_id"))


def apply_mail_payload(conn: sqlite3.Connection, payload: dict[str, Any], status: str) -> None:
    ensure_state_schema(conn)
    p = payload.get("payload", {})
    entity_ref = p.get("assignment_id") or p.get("candidate_id") or p.get("request_id") or p.get("evaluation_id") or p.get("synthesis_id")
    conn.execute(
        """
        INSERT INTO mail_payloads(payload_id, run_id, schema_id, schema_version, kind, sender_id, receiver_id, route_id, entity_ref, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(payload_id) DO UPDATE SET status=excluded.status, updated_at=excluded.updated_at
        """,
        (
            payload["payload_id"],
            payload["run_id"],
            payload["schema_id"],
            payload["schema_version"],
            payload["kind"],
            payload["sender_id"],
            payload["receiver_id"],
            payload.get("route_id"),
            entity_ref,
            status,
            now_iso(),
            now_iso(),
        ),
    )
    conn.commit()


@email.command("apply")
@click.argument("name_or_schema")
@click.option("--payload", "payload_path", required=True, type=click.Path(path_type=Path))
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--status", default="processed", type=click.Choice(["created", "validated", "rendered", "sent", "received", "processed", "archived", "failed", "repaired"]))
def email_apply(name_or_schema: str, payload_path: Path, db_path: Path, status: str) -> None:
    entry = resolve_template(name_or_schema)
    payload = read_payload(payload_path)
    errors = validate_payload(entry, payload)
    if errors:
        output("email apply", {"valid": False, "errors": errors}, run_id=payload.get("run_id"), success=False)
        raise SystemExit(1)
    conn = open_existing_db(db_path)
    apply_mail_payload(conn, payload, status)
    output("email apply", {"payload_id": payload["payload_id"], "status": status, "mailbox_delivery": "not-performed"}, run_id=payload.get("run_id"))


@email.command("query")
@click.option("--name-or-schema")
@click.option("--db", "db_path", type=click.Path(path_type=Path))
@click.option("--explain", is_flag=True)
def email_query(name_or_schema: str | None, db_path: Path | None, explain: bool) -> None:
    registry = templates_registry()
    if name_or_schema:
        registry = [resolve_template(name_or_schema)]
    data: dict[str, Any] = {"templates": registry}
    if db_path:
        conn = open_existing_db(db_path)
        data["payloads"] = rows(conn, "SELECT payload_id, schema_id, sender_id, receiver_id, status, entity_ref, updated_at FROM mail_payloads ORDER BY updated_at DESC LIMIT 50")
    if explain:
        data["explain"] = [{"source_key": f"templates.{e['name']}", "description": e.get("description", "")} for e in registry]
    output("email query", data)


@cli.group()
def state() -> None:
    """State initialization, validation, query, and export."""


@state.command("init")
@click.option("--run-id", required=True)
@click.option("--db", "db_path", type=click.Path(path_type=Path))
def state_init(run_id: str, db_path: Path | None) -> None:
    db = db_path or default_db(run_id)
    db.parent.mkdir(parents=True, exist_ok=True)
    conn = db_connect(db)
    ensure_state_schema(conn)
    seed = load_toml(rel_execplan("specs/state/seed.toml"))
    ts = now_iso()
    conn.execute(
        "INSERT OR REPLACE INTO control_state(run_id, run_state, execution_mode, plan_revision, operator_stop_requested, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
        (run_id, seed["seed"]["run_state"], seed["seed"]["execution_mode"], seed["seed"]["plan_revision"], int(seed["seed"]["operator_stop_requested"]), ts),
    )
    for p in seed.get("participants", []):
        conn.execute(
            "INSERT OR REPLACE INTO participants(participant_id, role_id, managed_agent, workspace_required, mailbox_required, status) VALUES (?, ?, ?, ?, ?, ?)",
            (p["participant_id"], p["role_id"], int(p["managed_agent"]), int(p["workspace_required"]), int(p["mailbox_required"]), "planned"),
        )
    conn.commit()
    output("state init", {"db": str(db), "participants_seeded": len(seed.get("participants", []))}, run_id=run_id)


@state.command("validate")
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--explain", is_flag=True)
def state_validate(db_path: Path, explain: bool) -> None:
    conn = open_existing_db(db_path)
    ensure_state_schema(conn)
    diagnostics = []
    fk = rows(conn, "PRAGMA foreign_key_check")
    if fk:
        output("state validate", {"foreign_key_violations": fk}, success=False)
        raise SystemExit(1)
    diagnostics.append("foreign keys ok")
    inv_path = rel_execplan("specs/state/invariants.toml")
    inv = load_toml(inv_path).get("invariants", [])
    failures = []
    for item in inv:
        if item.get("expect") != "violations == 0":
            continue
        row = conn.execute(item["query"]).fetchone()
        violations = row["violations"] if row and "violations" in row.keys() else list(row)[0]
        if violations != 0:
            failures.append({"id": item["id"], "violations": violations, "description": item["description"]})
    data: dict[str, Any] = {"valid": not failures, "invariant_failures": failures}
    if explain:
        data["explain"] = explain_toml(inv_path)
    output("state validate", data, diagnostics=diagnostics, success=not failures)
    if failures:
        raise SystemExit(1)


@state.command("query")
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--view", default="summary", type=click.Choice(["summary", "coder-slots", "blockers", "mail", "current-best"]))
@click.option("--cycle-id")
def state_query(db_path: Path, view: str, cycle_id: str | None) -> None:
    conn = open_existing_db(db_path)
    data: dict[str, Any] = {"view": view}
    if view == "summary":
        data["control_state"] = rows(conn, "SELECT * FROM control_state")
        data["participants"] = rows(conn, "SELECT participant_id, role_id, status, workspace_ref, mailbox_ref FROM participants")
    elif view == "coder-slots":
        if cycle_id:
            data["assignments"] = rows(conn, "SELECT assignment_id, cycle_id, owner_participant_id, coder_slot, status, retry_count FROM assignments WHERE cycle_id=?", (cycle_id,))
        else:
            data["assignments"] = rows(conn, "SELECT assignment_id, cycle_id, owner_participant_id, coder_slot, status, retry_count FROM assignments ORDER BY updated_at DESC LIMIT 20")
    elif view == "blockers":
        data["waiting_for_gpu"] = rows(conn, "SELECT * FROM waiting_for_gpu WHERE status IN ('waiting', 'retrying')")
        data["retry_records"] = rows(conn, "SELECT * FROM retry_records WHERE status IN ('retry_pending', 'failure_reported')")
    elif view == "mail":
        data["mail_payloads"] = rows(conn, "SELECT payload_id, schema_id, sender_id, receiver_id, status, entity_ref, updated_at FROM mail_payloads ORDER BY updated_at DESC LIMIT 50")
    elif view == "current-best":
        data["current_best"] = rows(conn, "SELECT * FROM current_best_history ORDER BY written_at DESC LIMIT 10")
    output("state query", data)


@state.command("export")
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
def state_export(db_path: Path) -> None:
    conn = open_existing_db(db_path)
    data = {
        "control_state": rows(conn, "SELECT * FROM control_state"),
        "open_assignments": rows(conn, "SELECT assignment_id, cycle_id, owner_participant_id, status, retry_count FROM assignments WHERE status NOT IN ('closed', 'synthesized')"),
        "blockers": {
            "waiting_for_gpu": rows(conn, "SELECT * FROM waiting_for_gpu WHERE status IN ('waiting', 'retrying')"),
            "retry_records": rows(conn, "SELECT * FROM retry_records WHERE status IN ('retry_pending', 'failure_reported')"),
        },
        "latest_evaluations": rows(conn, "SELECT * FROM evaluation_reports ORDER BY created_at DESC LIMIT 10"),
    }
    output("state export", data)


@cli.group()
def record() -> None:
    """Record validation and controlled application."""


@record.command("validate")
@click.argument("name_or_schema")
@click.option("--payload", "payload_path", required=True, type=click.Path(path_type=Path))
def record_validate(name_or_schema: str, payload_path: Path) -> None:
    entry = resolve_template(name_or_schema)
    payload = read_payload(payload_path)
    errors = validate_payload(entry, payload)
    output("record validate", {"valid": not errors, "errors": errors, "schema_id": entry["schema_id"]}, run_id=payload.get("run_id"), success=not errors)
    if errors:
        raise SystemExit(1)


@record.command("apply")
@click.argument("name_or_schema")
@click.option("--payload", "payload_path", required=True, type=click.Path(path_type=Path))
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--status", default="processed", type=click.Choice(["created", "validated", "rendered", "sent", "received", "processed", "archived", "failed", "repaired"]))
def record_apply(name_or_schema: str, payload_path: Path, db_path: Path, status: str) -> None:
    entry = resolve_template(name_or_schema)
    payload = read_payload(payload_path)
    errors = validate_payload(entry, payload)
    if errors:
        output("record apply", {"valid": False, "errors": errors}, run_id=payload.get("run_id"), success=False)
        raise SystemExit(1)
    conn = open_existing_db(db_path)
    apply_mail_payload(conn, payload, status)
    output("record apply", {"applied_family": "mail_payloads", "payload_id": payload["payload_id"], "status": status}, run_id=payload.get("run_id"))


@cli.group()
def control() -> None:
    """Run control and manual-mode helpers."""


def control_row(conn: sqlite3.Connection, run_id: str) -> dict[str, Any]:
    row = conn.execute("SELECT * FROM control_state WHERE run_id=?", (run_id,)).fetchone()
    if row:
        return dict(row)
    return {"run_id": run_id, "run_state": "not_started", "execution_mode": "auto", "plan_revision": PLAN_REVISION, "operator_stop_requested": 0, "updated_at": None}


@control.command("status")
@click.option("--run-id", required=True)
@click.option("--db", "db_path", type=click.Path(path_type=Path))
@click.option("--explain", is_flag=True)
def control_status(run_id: str, db_path: Path | None, explain: bool) -> None:
    data: dict[str, Any] = {"run_id": run_id, "notifier_posture": "platform-owned-by-houmao-agent-gateway"}
    warnings: list[str] = []
    if db_path and db_path.exists():
        conn = db_connect(db_path)
        data["control_state"] = control_row(conn, run_id)
        if table_exists(conn, "assignments"):
            data["active_assignments"] = rows(conn, "SELECT assignment_id, cycle_id, owner_participant_id, status, retry_count FROM assignments WHERE status NOT IN ('closed', 'synthesized')")
            data["blockers"] = {
                "waiting_for_gpu": rows(conn, "SELECT * FROM waiting_for_gpu WHERE status IN ('waiting', 'retrying')"),
                "retry_records": rows(conn, "SELECT * FROM retry_records WHERE status IN ('retry_pending', 'failure_reported')"),
            }
    else:
        data["control_state"] = {"run_id": run_id, "run_state": "not_started", "execution_mode": "auto"}
        warnings.append("state db absent; reported default control posture")
    if explain:
        data["explain"] = explain_toml(rel_execplan("specs/run/control.toml"))
    output("control status", data, run_id=run_id, warnings=warnings)


@control.command("get-mode")
@click.option("--run-id", required=True)
@click.option("--db", "db_path", type=click.Path(path_type=Path))
def control_get_mode(run_id: str, db_path: Path | None) -> None:
    if db_path and db_path.exists():
        conn = db_connect(db_path)
        row = control_row(conn, run_id)
        source = str(db_path)
    else:
        row = {"execution_mode": "auto"}
        source = "default-contract"
    output("control get-mode", {"execution_mode": row["execution_mode"], "source": source}, run_id=run_id)


def record_operator_action(conn: sqlite3.Connection, run_id: str, action: str, *, mode: str | None = None, run_state: str | None = None, rationale: str | None = None) -> None:
    ensure_state_schema(conn)
    current = control_row(conn, run_id)
    new_state = run_state or current["run_state"]
    new_mode = mode or current["execution_mode"]
    ts = now_iso()
    conn.execute(
        "INSERT OR REPLACE INTO control_state(run_id, run_state, execution_mode, plan_revision, operator_stop_requested, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
        (run_id, new_state, new_mode, PLAN_REVISION, int(action == "stop"), ts),
    )
    conn.execute(
        "INSERT INTO operator_intent_events(operator_event_id, run_id, action, target_refs, rationale, applied_run_state, applied_execution_mode, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (f"operator-{action}-{ts}", run_id, action, "", rationale or "", new_state, new_mode, ts),
    )
    conn.commit()


@control.command("set-mode")
@click.option("--run-id", required=True)
@click.option("--mode", required=True, type=click.Choice(["auto", "manual"]))
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--rationale", default="")
def control_set_mode(run_id: str, mode: str, db_path: Path, rationale: str) -> None:
    conn = open_existing_db(db_path)
    record_operator_action(conn, run_id, "mode-switch", mode=mode, rationale=rationale)
    output("control set-mode", {"execution_mode": mode, "manual_is_pause": False}, run_id=run_id)


@control.command("pause")
@click.option("--run-id", required=True)
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--rationale", default="")
def control_pause(run_id: str, db_path: Path, rationale: str) -> None:
    conn = open_existing_db(db_path)
    record_operator_action(conn, run_id, "pause", run_state="paused", rationale=rationale)
    output("control pause", {"run_state": "paused"}, run_id=run_id)


@control.command("resume")
@click.option("--run-id", required=True)
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--rationale", default="")
def control_resume(run_id: str, db_path: Path, rationale: str) -> None:
    conn = open_existing_db(db_path)
    record_operator_action(conn, run_id, "resume", run_state="running", rationale=rationale)
    output("control resume", {"run_state": "running"}, run_id=run_id)


@control.command("stop")
@click.option("--run-id", required=True)
@click.option("--db", "db_path", required=True, type=click.Path(path_type=Path))
@click.option("--rationale", default="")
def control_stop(run_id: str, db_path: Path, rationale: str) -> None:
    conn = open_existing_db(db_path)
    record_operator_action(conn, run_id, "stop", run_state="stopped", rationale=rationale)
    output("control stop", {"run_state": "stopped", "terminal_authority": "human-operator-stop"}, run_id=run_id)


@control.command("manual-context")
@click.option("--run-id", required=True)
@click.option("--participant-id", required=True)
@click.option("--db", "db_path", type=click.Path(path_type=Path))
def control_manual_context(run_id: str, participant_id: str, db_path: Path | None) -> None:
    row = {"run_state": "not_started", "execution_mode": "auto"}
    pending_mail: list[dict[str, Any]] = []
    active_assignments: list[dict[str, Any]] = []
    if db_path and db_path.exists():
        conn = db_connect(db_path)
        row = control_row(conn, run_id)
        pending_mail = rows(conn, "SELECT payload_id, schema_id, sender_id, receiver_id, status, entity_ref FROM mail_payloads WHERE receiver_id=? AND status IN ('sent', 'received', 'validated', 'rendered')", (participant_id,))
        active_assignments = rows(conn, "SELECT assignment_id, cycle_id, owner_participant_id, status, retry_count FROM assignments WHERE owner_participant_id=? AND status NOT IN ('closed', 'synthesized')", (participant_id,))
    data = {
        "run_id": run_id,
        "participant_id": participant_id,
        "run_state": row["run_state"],
        "execution_mode": row["execution_mode"],
        "pending_mail_refs": pending_mail,
        "active_handoff_refs": active_assignments,
        "allowed_actions": ["process_one_mail", "run_one_tick_pass", "record_context", "send_required_reply_or_report"],
        "stop_after_one_pass": True,
    }
    output("control manual-context", data, run_id=run_id)


def main(argv: list[str] | None = None) -> None:
    cli.main(args=argv, prog_name="lead-code-synth-research-harness")


if __name__ == "__main__":
    main(sys.argv[1:])
