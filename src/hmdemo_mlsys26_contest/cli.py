"""Command-line interface for repo-local project tooling."""

from __future__ import annotations

import json
from pathlib import Path

import click

from hmdemo_mlsys26_contest.errors import ProjectCliError
from hmdemo_mlsys26_contest.variants import VariantManager
from hmdemo_mlsys26_contest.workloads import WorkloadManager


def _invoke(action):
    """Run a CLI action and map project errors to Click exceptions."""
    try:
        return action()
    except ProjectCliError as exc:
        raise click.ClickException(str(exc)) from exc


@click.group()
def main() -> None:
    """Repo-local project tooling."""


@main.group()
def variant() -> None:
    """Manage registered CUDA kernel variants."""


@main.group()
def workload() -> None:
    """Manage workload sources, records, and registered workload sets."""


@workload.group("source")
def workload_source() -> None:
    """Manage named workload sources."""


@workload.group("set")
def workload_set() -> None:
    """Manage named workload sets."""


@variant.command("list")
def list_variants() -> None:
    """List registered variants."""
    entries = _invoke(lambda: VariantManager.discover().list_variants())
    click.echo("variant_id\tlanguage\tdefinition\tpath")
    for entry in entries:
        click.echo(f"{entry.variant_id}\t{entry.language}\t{entry.definition}\t{entry.path}")


@variant.command("show")
@click.argument("variant_id")
def show_variant(variant_id: str) -> None:
    """Show one registered variant."""
    entry, manifest = _invoke(lambda: VariantManager.discover().show_variant(variant_id))
    click.echo(f"variant_id = {entry.variant_id}")
    click.echo(f"language = {entry.language}")
    click.echo(f"definition = {manifest.definition}")
    click.echo(f"path = {entry.path}")
    click.echo(f"entry_point = {manifest.build.entry_point}")
    click.echo(f"binding = {manifest.build.binding or ''}")
    click.echo(
        "destination_passing_style = "
        f"{str(manifest.build.destination_passing_style).lower()}"
    )


@variant.command("new")
@click.argument("variant_id")
@click.option("--definition", required=True, help="Contest definition ID.")
@click.option("--template", "template_name", default=None, help="Template bundle name.")
@click.option("--deploy", is_flag=True, help="Deploy the variant after creation.")
def new_variant(
    variant_id: str,
    definition: str,
    template_name: str | None,
    deploy: bool,
) -> None:
    """Create a new variant from a tracked template."""
    entry = _invoke(
        lambda: VariantManager.discover().new_variant(
            variant_id=variant_id,
            definition=definition,
            template_name=template_name,
            deploy=deploy,
        )
    )
    click.echo(f"Created variant {entry.variant_id} at variants/{entry.path}")
    if deploy:
        click.echo(f"Deployed variant {entry.variant_id} to solution/cuda/")


@variant.command("deploy")
@click.argument("variant_id")
def deploy_variant(variant_id: str) -> None:
    """Deploy a registered variant into solution/cuda/."""
    _invoke(lambda: VariantManager.discover().deploy_variant(variant_id))
    click.echo(f"Deployed variant {variant_id} to solution/cuda/")


@variant.command("stock")
@click.argument("variant_id")
def stock_variant(variant_id: str) -> None:
    """Stock the live CUDA bundle back into a registered variant."""
    _invoke(lambda: VariantManager.discover().stock_variant(variant_id))
    click.echo(f"Stocked live CUDA bundle into variant {variant_id}")


@variant.command("status")
def status_variant() -> None:
    """Compare the live CUDA bundle against registered variants."""
    matches = _invoke(lambda: VariantManager.discover().status())
    if not matches:
        click.echo("No exact registered variant matches the live CUDA bundle.")
        return
    click.echo("Exact live matches:")
    for variant_id in matches:
        click.echo(f"- {variant_id}")


@variant.command("diff")
@click.argument("variant_id")
def diff_variant(variant_id: str) -> None:
    """Diff the live CUDA bundle against one stored variant."""
    diffs = _invoke(lambda: VariantManager.discover().diff_variant(variant_id))
    if not diffs:
        click.echo(f"No differences between live CUDA bundle and variant {variant_id}.")
        return
    for file_name, diff_text in diffs.items():
        click.echo(f"=== {file_name} ===")
        click.echo(diff_text.rstrip())


@workload_source.command("list")
def list_workload_sources() -> None:
    """List named workload sources."""
    sources = _invoke(lambda: WorkloadManager.discover().list_sources())
    click.echo("name\tkind\tpath")
    for source in sources:
        if source.kind == "dataset-root":
            rendered_path = source.path
        else:
            rendered_path = f"{source.dataset_root}::{source.workload_dir}"
        click.echo(f"{source.name}\t{source.kind}\t{rendered_path}")


@workload_source.command("show")
@click.argument("name")
def show_workload_source(name: str) -> None:
    """Show one named workload source."""
    source = _invoke(lambda: WorkloadManager.discover().show_source(name))
    click.echo(f"name = {source.name}")
    click.echo(f"kind = {source.kind}")
    if source.kind == "dataset-root":
        click.echo(f"path = {source.path}")
    else:
        click.echo(f"dataset_root = {source.dataset_root}")
        click.echo(f"workload_dir = {source.workload_dir}")


@workload_source.command("register")
@click.argument("name")
@click.option("--kind", type=click.Choice(["dataset-root", "workload-dir"]), required=True)
@click.option("--path", default=None, help="Dataset root path for dataset-root sources.")
@click.option("--dataset-root", default=None, help="Dataset root path for workload-dir sources.")
@click.option("--workload-dir", default=None, help="Workload dir path for workload-dir sources.")
def register_workload_source(
    name: str,
    kind: str,
    path: str | None,
    dataset_root: str | None,
    workload_dir: str | None,
) -> None:
    """Register one named workload source."""
    source = _invoke(
        lambda: WorkloadManager.discover().register_source(
            name=name,
            kind=kind,
            path=path,
            dataset_root=dataset_root,
            workload_dir=workload_dir,
        )
    )
    click.echo(f"Registered workload source {source.name}.")


@workload_source.command("remove")
@click.argument("name")
def remove_workload_source(name: str) -> None:
    """Remove one named workload source."""
    _invoke(lambda: WorkloadManager.discover().remove_source(name))
    click.echo(f"Removed workload source {name}.")


@workload.command("list")
@click.option("--source", "source_name", default=None, help="Named workload source.")
@click.option("--definition", default=None, help="Exact contest definition ID.")
@click.option("--uuid-prefix", default=None, help="Filter listed workloads by UUID prefix.")
@click.option("--limit", type=int, default=None, help="Maximum workload rows to show.")
def list_workloads(
    source_name: str | None,
    definition: str | None,
    uuid_prefix: str | None,
    limit: int | None,
) -> None:
    """List workloads from a resolved source and definition."""
    records = _invoke(
        lambda: WorkloadManager.discover().list_workloads(
            source_name=source_name,
            definition=definition,
            uuid_prefix=uuid_prefix,
            limit=limit,
        )
    )
    click.echo("uuid\tjson")
    for record in records:
        click.echo(f"{record.uuid}\t{json.dumps(record.data, sort_keys=True)}")


@workload.command("show")
@click.argument("selector")
@click.option("--source", "source_name", default=None, help="Named workload source.")
@click.option("--definition", default=None, help="Exact contest definition ID.")
def show_workload(selector: str, source_name: str | None, definition: str | None) -> None:
    """Show one workload record by exact UUID or unique prefix."""
    record = _invoke(
        lambda: WorkloadManager.discover().show_workload(
            selector=selector,
            source_name=source_name,
            definition=definition,
        )
    )
    click.echo(json.dumps(record.data, sort_keys=True, indent=2))


@workload_set.command("list")
def list_workload_sets() -> None:
    """List named workload sets."""
    sets = _invoke(lambda: WorkloadManager.discover().list_sets())
    click.echo("name\tsource\tdefinition\tworkloads")
    for workload_set in sets:
        click.echo(
            f"{workload_set.name}\t{workload_set.source}\t"
            f"{workload_set.definition}\t{len(workload_set.workloads)}"
        )


@workload_set.command("show")
@click.argument("name")
def show_workload_set(name: str) -> None:
    """Show one named workload set."""
    workload_set = _invoke(lambda: WorkloadManager.discover().show_set(name))
    click.echo(f"name = {workload_set.name}")
    click.echo(f"source = {workload_set.source}")
    click.echo(f"definition = {workload_set.definition}")
    click.echo("workloads =")
    for uuid in workload_set.workloads:
        click.echo(f"- {uuid}")


@workload_set.command("register")
@click.argument("name")
@click.option("--source", "source_name", required=True, help="Named workload source.")
@click.option("--definition", required=True, help="Exact contest definition ID.")
@click.option("--workload", "workloads", multiple=True, help="Workload UUID or prefix.")
@click.option(
    "--from-file",
    type=click.Path(path_type=Path, exists=True, dir_okay=False),
    default=None,
    help="File with one workload UUID or prefix per line.",
)
def register_workload_set(
    name: str,
    source_name: str,
    definition: str,
    workloads: tuple[str, ...],
    from_file: Path | None,
) -> None:
    """Register one named workload set."""
    workload_set = _invoke(
        lambda: WorkloadManager.discover().register_set(
            name=name,
            source_name=source_name,
            definition=definition,
            workload_selectors=workloads,
            from_file=from_file,
        )
    )
    click.echo(
        f"Registered workload set {workload_set.name} with "
        f"{len(workload_set.workloads)} workloads."
    )


@workload_set.command("remove")
@click.argument("name")
def remove_workload_set(name: str) -> None:
    """Remove one named workload set."""
    _invoke(lambda: WorkloadManager.discover().remove_set(name))
    click.echo(f"Removed workload set {name}.")
