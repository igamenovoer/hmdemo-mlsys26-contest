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
    assert "--profile-plugin" in main
    assert "--profile-device" in main
    assert "create_or_update_artifact" not in main.partition('add_subcommand("run"')[2]


def test_cpp_profiler_exposes_nvbench_stopping_controls() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert "--stopping-criterion" in main
    assert "--min-samples" in main
    assert "--target-samples" in main
    assert "--max-noise" in main
    assert "--min-time" in main
    assert 'CLI::IsMember({"sample-count", "stdrel", "entropy"})' in main


def test_cpp_profiler_uses_nvbench_native_run_options() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert "--cold-warmup-runs" in main
    assert "--devices" in main
    assert 'add_option("--iterations"' not in main
    assert 'add_option("--warmup-runs"' not in main
    assert 'add_option("--device"' not in main
    assert 'add_option("--num-trials"' not in main
    assert 'add_option("--random-seed"' not in main
    assert 'add_option("--rtol"' not in main
    assert 'add_option("--atol"' not in main
    assert 'add_option("--required-matched-ratio"' not in main


def test_cpp_profiler_default_and_explicit_sample_mapping() -> None:
    main = (ROOT / "cpp/src/main.cpp").read_text()
    assert 'has_stdrel_params ? "stdrel" : "sample-count"' in main
    assert "run.iterations" not in main
    assert "min_samples_explicit" in main
    assert "target_samples_explicit" in main
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
    assert "plugin_abi_version" in artifact
    assert "plugin_library" in artifact
    assert "cuda_toolkit_root" in artifact
    assert "compiler_flags" in artifact
    assert "workload" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]
    assert "stopping" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]
    assert "samples" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]


def test_cpp_profiler_builds_kernel_plugin_not_runner_artifact() -> None:
    artifact = (ROOT / "cpp/src/artifact.cpp").read_text()
    main = (ROOT / "cpp/src/main.cpp").read_text()
    plugin_cmake = artifact.partition("std::string render_plugin_cmake")[2].partition("std::string render_plugin_source")[0]
    create_artifact = artifact.partition("std::filesystem::path create_or_update_artifact")[2]
    assert "add_library(hm_profile_kernel_plugin SHARED src/plugin.cu)" in plugin_cmake
    assert "add_subdirectory" not in plugin_cmake
    assert "nvbench" not in plugin_cmake.lower()
    assert 'add_option("--nvbench-source"' not in main
    assert "write_text(src_dir / \"plugin.cu\"" in create_artifact
    assert "--target hm_profile_kernel_plugin" in create_artifact
    assert "runner_binary" not in artifact.partition("nlohmann::json identity =")[2].partition(";")[0]


def test_cpp_profiler_has_static_runner_and_plugin_loader() -> None:
    cmake = (ROOT / "cpp/CMakeLists.txt").read_text()
    runner = (ROOT / "cpp/runner/runner.cu").read_text()
    loader = (ROOT / "cpp/src/plugin_loader.cpp").read_text()
    abi = (ROOT / "cpp/include/hmdemo_nvbench_profile/plugin_abi.h").read_text()
    assert "HM_NVPROFILE_BUILD_STATIC_RUNNER" in cmake
    assert "runner/runner.cu" in cmake
    assert "--profile-plugin" in runner
    assert "moe_tvm_ffi::Kernel" not in runner
    assert "g_plugin->moe().invoke" in runner
    assert "TVMFFIEnvSetStream" in runner
    assert "dlopen" in loader
    assert "hm_profile_plugin_abi_version" in loader
    assert "hm_profile_moe_kernel_v1" in loader
    assert "HM_PROFILE_PLUGIN_ABI_VERSION" in abi
    assert "HM_PROFILE_PLUGIN_ADAPTER_TVM_FFI_MOE" in abi
