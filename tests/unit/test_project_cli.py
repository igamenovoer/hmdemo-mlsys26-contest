from __future__ import annotations

import tomllib
from pathlib import Path

import pytest
from click.testing import CliRunner

from hmdemo_mlsys26_contest.cli import main
from hmdemo_mlsys26_contest.config_store import load_variant_entries, load_workload_config
from hmdemo_mlsys26_contest.errors import ProjectCliError
from hmdemo_mlsys26_contest.paths import resolve_repo_paths

MOE_DEFINITION = "moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048"


def make_repo(
    root: Path,
    *,
    config_language: str = "cuda",
    definition: str = MOE_DEFINITION,
) -> None:
    (root / "pyproject.toml").write_text("[project]\nname = 'test-project'\n")
    entry_point = "kernel.cu::kernel" if config_language == "cuda" else "kernel"
    build_lines = [
        "[build]",
        f'language = "{config_language}"',
        f'entry_point = "{entry_point}"',
    ]
    if config_language == "cuda":
        build_lines.extend(
            [
                'binding = "tvm-ffi"',
                "destination_passing_style = true",
            ]
        )
    (root / "config.toml").write_text(
        "\n".join(
            [
                "[solution]",
                'name = "test-solution"',
                f'definition = "{definition}"',
                'author = "team-name"',
                "",
                *build_lines,
                "",
            ]
        )
    )
    (root / "solution/cuda").mkdir(parents=True)
    (root / "solution/cuda/kernel.cu").write_text("// live kernel\n")
    (root / "solution/cuda/binding.py").write_text("# live binding\n")
    (root / "variants/templates/cuda-default").mkdir(parents=True)
    (root / "variants/cuda").mkdir(parents=True)
    (root / "variants/templates/cuda-default/variant.toml").write_text(
        "\n".join(
            [
                'id = "template"',
                'language = "cuda"',
                'definition = "replace-me"',
                "",
                "[build]",
                'entry_point = "kernel.cu::kernel"',
                'binding = "tvm-ffi"',
                "destination_passing_style = true",
                "",
            ]
        )
    )
    (root / "variants/templates/cuda-default/kernel.cu").write_text("// template kernel\n")
    (root / "variants/templates/cuda-default/binding.py").write_text("# template binding\n")
    (root / "configs").mkdir()
    (root / "configs/variants.toml").write_text(
        'version = 1\ndefault_template = "cuda-default"\n\n[variants]\n'
    )
    write_workload_fixture(root)


def write_workload_fixture(root: Path) -> None:
    workload_dir = root / "dataset/workloads/moe"
    workload_dir.mkdir(parents=True)
    records = [
        workload_record("2e69caee-ae5c-473b-aa99-5dc6659829d4", 1),
        workload_record("2f000000-1111-2222-3333-444444444444", 2),
        workload_record("4822167c-dae5-4bb1-bb53-e4adb256245b", 3),
    ]
    (workload_dir / f"{MOE_DEFINITION}.jsonl").write_text("\n".join(records) + "\n")
    (root / "configs/workloads.toml").write_text(
        "\n".join(
            [
                "version = 1",
                'default_source = "contest-local"',
                "",
                "[sources.contest-local]",
                'kind = "dataset-root"',
                'path = "dataset"',
                "",
                "[sets.moe-minimal]",
                'source = "contest-local"',
                f'definition = "{MOE_DEFINITION}"',
                "workloads = [",
                '    "2e69caee-ae5c-473b-aa99-5dc6659829d4",',
                "]",
                "",
            ]
        )
    )


def workload_record(uuid: str, seq_len: int) -> str:
    return (
        '{"definition": "'
        + MOE_DEFINITION
        + '", "solution": null, "workload": {"uuid": "'
        + uuid
        + '", "axes": {"seq_len": '
        + str(seq_len)
        + '}, "inputs": {}}, "evaluation": null}'
    )


@pytest.fixture
def repo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    make_repo(tmp_path)
    monkeypatch.chdir(tmp_path)
    return tmp_path


def test_config_loads_initial_files(repo: Path) -> None:
    paths = resolve_repo_paths(repo)

    default_template, entries = load_variant_entries(paths)
    default_source, sources, sets = load_workload_config(paths)

    assert default_template == "cuda-default"
    assert entries == {}
    assert default_source == "contest-local"
    assert sources["contest-local"].path == "dataset"
    assert sets["moe-minimal"].workloads == ("2e69caee-ae5c-473b-aa99-5dc6659829d4",)


def test_invalid_variant_id_in_config_fails(repo: Path) -> None:
    (repo / "configs/variants.toml").write_text(
        "\n".join(
            [
                "version = 1",
                'default_template = "cuda-default"',
                "",
                "[variants.Bad_Name]",
                'language = "cuda"',
                f'definition = "{MOE_DEFINITION}"',
                'path = "cuda/Bad_Name"',
                'entry_point = "kernel.cu::kernel"',
                'binding = "tvm-ffi"',
                "destination_passing_style = true",
                "",
            ]
        )
    )

    with pytest.raises(ProjectCliError, match="lowercase kebab-case"):
        load_variant_entries(resolve_repo_paths(repo))


def test_variant_commands_cover_create_deploy_stock_status_and_diff(repo: Path) -> None:
    runner = CliRunner()

    result = runner.invoke(
        main,
        ["variant", "new", "moe-trial", "--definition", MOE_DEFINITION, "--deploy"],
    )
    assert result.exit_code == 0, result.output
    assert "Created variant moe-trial" in result.output
    assert (repo / "variants/cuda/moe-trial/kernel.cu").read_text() == "// template kernel\n"
    assert (repo / "solution/cuda/kernel.cu").read_text() == "// template kernel\n"
    manifest = tomllib.loads((repo / "variants/cuda/moe-trial/variant.toml").read_text())
    assert manifest["build"]["entry_point"] == "kernel.cu::kernel"
    assert manifest["build"]["binding"] == "tvm-ffi"
    assert manifest["build"]["destination_passing_style"] is True

    show = runner.invoke(main, ["variant", "show", "moe-trial"])
    assert show.exit_code == 0, show.output
    assert f"definition = {MOE_DEFINITION}" in show.output
    assert "entry_point = kernel.cu::kernel" in show.output

    status = runner.invoke(main, ["variant", "status"])
    assert status.exit_code == 0, status.output
    assert "- moe-trial" in status.output

    (repo / "solution/cuda/kernel.cu").write_text("// edited live kernel\n")
    diff = runner.invoke(main, ["variant", "diff", "moe-trial"])
    assert diff.exit_code == 0, diff.output
    assert "=== kernel.cu ===" in diff.output
    assert "+// edited live kernel" in diff.output

    stock = runner.invoke(main, ["variant", "stock", "moe-trial"])
    assert stock.exit_code == 0, stock.output
    assert (repo / "variants/cuda/moe-trial/kernel.cu").read_text() == "// edited live kernel\n"
    stocked_manifest = tomllib.loads((repo / "variants/cuda/moe-trial/variant.toml").read_text())
    assert stocked_manifest["build"]["entry_point"] == "kernel.cu::kernel"
    assert stocked_manifest["build"]["binding"] == "tvm-ffi"
    assert stocked_manifest["build"]["destination_passing_style"] is True

    post_stock_diff = runner.invoke(main, ["variant", "diff", "moe-trial"])
    assert post_stock_diff.exit_code == 0, post_stock_diff.output
    assert "No differences" in post_stock_diff.output


def test_variant_new_uses_template_build_metadata_when_live_config_is_not_cuda(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    make_repo(tmp_path, config_language="triton")
    monkeypatch.chdir(tmp_path)

    result = CliRunner().invoke(
        main,
        ["variant", "new", "moe-trial", "--definition", MOE_DEFINITION],
    )

    assert result.exit_code == 0, result.output
    _, entries = load_variant_entries(resolve_repo_paths(tmp_path))
    assert entries["moe-trial"].build.entry_point == "kernel.cu::kernel"
    assert entries["moe-trial"].build.binding == "tvm-ffi"
    assert entries["moe-trial"].build.destination_passing_style is True


def test_variant_rejects_invalid_id_before_filesystem_changes(repo: Path) -> None:
    result = CliRunner().invoke(
        main,
        ["variant", "new", "Bad_Name", "--definition", MOE_DEFINITION],
    )

    assert result.exit_code != 0
    assert "lowercase kebab-case" in result.output
    assert not (repo / "variants/cuda/Bad_Name").exists()


def test_variant_deploy_rejects_live_config_mismatch(repo: Path) -> None:
    runner = CliRunner()
    create = runner.invoke(
        main,
        ["variant", "new", "other-trial", "--definition", "other_definition"],
    )
    assert create.exit_code == 0, create.output

    before = (repo / "solution/cuda/kernel.cu").read_text()
    deploy = runner.invoke(main, ["variant", "deploy", "other-trial"])

    assert deploy.exit_code != 0
    assert "does not match" in deploy.output
    assert "solution.definition" in deploy.output
    assert (repo / "solution/cuda/kernel.cu").read_text() == before


def test_workload_source_and_set_commands(repo: Path) -> None:
    runner = CliRunner()

    sources = runner.invoke(main, ["workload", "source", "list"])
    assert sources.exit_code == 0, sources.output
    assert "contest-local\tdataset-root\tdataset" in sources.output

    show_source = runner.invoke(main, ["workload", "source", "show", "contest-local"])
    assert show_source.exit_code == 0, show_source.output
    assert "path = dataset" in show_source.output

    register_source = runner.invoke(
        main,
        [
            "workload",
            "source",
            "register",
            "smoke-dir",
            "--kind",
            "workload-dir",
            "--dataset-root",
            "dataset",
            "--workload-dir",
            "dataset/workloads",
        ],
    )
    assert register_source.exit_code == 0, register_source.output

    remove_source = runner.invoke(main, ["workload", "source", "remove", "smoke-dir"])
    assert remove_source.exit_code == 0, remove_source.output

    listed = runner.invoke(
        main,
        ["workload", "list", "--definition", MOE_DEFINITION, "--limit", "1"],
    )
    assert listed.exit_code == 0, listed.output
    assert "2e69caee-ae5c-473b-aa99-5dc6659829d4" in listed.output

    shown = runner.invoke(
        main,
        ["workload", "show", "4822167c", "--definition", MOE_DEFINITION],
    )
    assert shown.exit_code == 0, shown.output
    assert '"uuid": "4822167c-dae5-4bb1-bb53-e4adb256245b"' in shown.output

    register_set = runner.invoke(
        main,
        [
            "workload",
            "set",
            "register",
            "moe-smoke",
            "--source",
            "contest-local",
            "--definition",
            MOE_DEFINITION,
            "--workload",
            "2e69caee",
            "--workload",
            "4822167c",
        ],
    )
    assert register_set.exit_code == 0, register_set.output
    assert "2 workloads" in register_set.output

    with (repo / "configs/workloads.toml").open("rb") as handle:
        data = tomllib.load(handle)
    assert data["sets"]["moe-smoke"]["workloads"] == [
        "2e69caee-ae5c-473b-aa99-5dc6659829d4",
        "4822167c-dae5-4bb1-bb53-e4adb256245b",
    ]

    show_set = runner.invoke(main, ["workload", "set", "show", "moe-smoke"])
    assert show_set.exit_code == 0, show_set.output
    assert "- 4822167c-dae5-4bb1-bb53-e4adb256245b" in show_set.output

    remove_set = runner.invoke(main, ["workload", "set", "remove", "moe-smoke"])
    assert remove_set.exit_code == 0, remove_set.output


def test_workload_selector_errors(repo: Path) -> None:
    runner = CliRunner()

    ambiguous = runner.invoke(
        main,
        ["workload", "show", "2", "--definition", MOE_DEFINITION],
    )
    assert ambiguous.exit_code != 0
    assert "ambiguous" in ambiguous.output

    unknown = runner.invoke(
        main,
        ["workload", "show", "zzz", "--definition", MOE_DEFINITION],
    )
    assert unknown.exit_code != 0
    assert "No workload matches" in unknown.output

    duplicate = runner.invoke(
        main,
        [
            "workload",
            "set",
            "register",
            "bad-set",
            "--source",
            "contest-local",
            "--definition",
            MOE_DEFINITION,
            "--workload",
            "2e69caee",
            "--workload",
            "2e69caee-ae5c-473b-aa99-5dc6659829d4",
        ],
    )
    assert duplicate.exit_code != 0
    assert "Duplicate workload selector" in duplicate.output


def test_project_cli_has_no_eval_timing_command(repo: Path) -> None:
    result = CliRunner().invoke(main, ["eval"])

    assert result.exit_code != 0
    assert "No such command" in result.output
