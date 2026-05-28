from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_cpp_profiler_scaffold_declares_conan_and_cmake() -> None:
    assert (ROOT / "cpp/conanfile.py").is_file()
    assert (ROOT / "cpp/CMakeLists.txt").is_file()
    conanfile = (ROOT / "cpp/conanfile.py").read_text()
    assert "cli11" in conanfile
    assert "nlohmann_json" in conanfile
    assert "fmt" in conanfile


def test_cpp_profiler_cli_keeps_build_and_run_separate() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert 'add_subcommand("build"' in main
    assert 'add_subcommand("run"' in main
    assert "--profile-device" in main
    assert "trial < run.num_trials" in main
    assert "--rtol, --atol, and --required-matched-ratio are unsupported" in main


def test_cpp_profiler_exposes_nvbench_stopping_controls() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert "--stopping-criterion" in main
    assert "--min-samples" in main
    assert "--target-samples" in main
    assert "--max-noise" in main
    assert "--min-time" in main
    assert 'CLI::IsMember({"sample-count", "stdrel", "entropy"})' in main


def test_cpp_profiler_default_and_explicit_sample_mapping() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert 'has_stdrel_params ? "stdrel" : "sample-count"' in main
    assert "effective_stopping_criterion == \"sample-count\" ? run.iterations : 0" in main
    assert "effective_min_samples" in main
    assert "effective_target_samples" in main
    assert 'args.push_back("--min-samples")' in main
    assert 'args.push_back("--target-samples")' in main


def test_cpp_profiler_stdrel_variance_mapping_and_validation() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert "max_noise_option->count() != 0" in main
    assert "min_time_option->count() != 0" in main
    assert "--max-noise and --min-time require the stdrel stopping criterion" in main
    assert "--target-samples requires the sample-count stopping criterion" in main
    assert 'args.push_back("--max-noise")' in main
    assert 'args.push_back("--min-time")' in main


def test_cpp_profiler_manifest_excludes_runtime_workload_inputs() -> None:
    artifact = (ROOT / "cpp/src/artifact.cpp").read_text()
    assert "kernel_sha" in artifact
    assert "compiler_flags" in artifact
    assert "workload" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]
    assert "stopping" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]
    assert "samples" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]
