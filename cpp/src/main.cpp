#include "hmdemo_nvbench_profile/artifact.hpp"
#include "hmdemo_nvbench_profile/trace.hpp"

#include <CLI/CLI.hpp>
#include <fmt/format.h>

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace hp = hmdemo::nvprofile;

namespace {

std::filesystem::path repo_root_from_cwd() {
  auto cwd = std::filesystem::current_path();
  for (auto path = cwd; !path.empty(); path = path.parent_path()) {
    if (std::filesystem::exists(path / "pyproject.toml") &&
        std::filesystem::exists(path / "openspec")) {
      return path;
    }
    if (path == path.root_path()) break;
  }
  return cwd.parent_path();
}

int run_command(const std::string& command) {
  const int status = std::system(command.c_str());
  if (status != 0) {
    throw std::runtime_error(fmt::format("command failed with status {}: {}", status, command));
  }
  return status;
}

std::filesystem::path default_runner_binary() {
  return repo_root_from_cwd() / "cpp/build/Release/hm-nvbench-runner";
}

std::string quote(const std::filesystem::path& path) {
  std::string text = path.string();
  std::string out = "'";
  for (char c : text) {
    if (c == '\'') out += "'\\''";
    else out += c;
  }
  out += "'";
  return out;
}

}  // namespace

int main(int argc, char** argv) try {
  CLI::App app{"C++ NVBench profiler for local contest kernels"};
  app.require_subcommand(1);

  hp::BuildOptions build;
  build.repo_root = repo_root_from_cwd();
  build.artifact_root = build.repo_root / "cpp/.cache/artifacts";
  build.cutlass_include_roots = hp::split_paths(HM_NVPROFILE_DEFAULT_CUTLASS_INCLUDE_ROOTS);

  auto* build_cmd = app.add_subcommand("build", "Build or refresh a per-kernel profiler plugin artifact");
  build_cmd->add_option("--kernel", build.kernel, "CUDA kernel source")->required()->check(CLI::ExistingFile);
  build_cmd->add_option("--definition", build.definition, "Contest definition id")->required();
  build_cmd->add_option("--adapter", build.adapter, "Definition adapter");
  build_cmd->add_option("--cuda-arch", build.cuda_arch, "CUDA architecture for generated plugin");
  build_cmd->add_option("--build-type", build.build_type, "CMake build type");
  build_cmd->add_option("--artifact-root", build.artifact_root, "Artifact root directory");
  build_cmd->add_option("--tvm-ffi-root", build.tvm_ffi_root, "TVM-FFI root")->check(CLI::ExistingDirectory);
  build_cmd->add_option("--include-root", build.include_roots, "Extra include root")->check(CLI::ExistingDirectory);
  build_cmd->add_option("--cutlass-include-root", build.cutlass_include_roots, "CUTLASS include root")->check(CLI::ExistingDirectory);
  build_cmd->add_option("--compiler-flag", build.compiler_flags, "Extra CUDA compiler flag");
  build_cmd->add_flag("--skip-compile", build.skip_compile, "Generate artifact sources and manifest without compiling");
  build_cmd->add_flag("--force", build.force, "Refresh artifact files even if the manifest matches");
  build_cmd->callback([&] {
    auto artifact = hp::create_or_update_artifact(build);
    std::cout << artifact << "\n";
  });

  struct RunOptions {
    std::filesystem::path artifact;
    std::filesystem::path runner_binary;
    std::filesystem::path dataset_root;
    std::string definition;
    std::vector<std::string> workloads;
    std::string workload_set;
    int cold_warmup_runs = 1;
    std::string stopping_criterion;
    int min_samples = 0;
    int target_samples = 0;
    double max_noise = 0.0;
    double min_time = 0.0;
    int timeout = 300;
    int devices = 0;
    std::filesystem::path json_output;
    std::filesystem::path csv_output;
    std::filesystem::path markdown_output;
    bool dry_run = false;
  } run;

  auto* run_cmd = app.add_subcommand("run", "Run an existing profiler artifact against runtime-selected workloads");
  run_cmd->add_option("--artifact", run.artifact, "Built plugin artifact directory")->required()->check(CLI::ExistingDirectory);
  run_cmd->add_option("--runner", run.runner_binary, "Reusable hm-nvbench-runner binary");
  run_cmd->add_option("--local", run.dataset_root, "FlashInfer Trace dataset root")->required()->check(CLI::ExistingDirectory);
  run_cmd->add_option("--definition", run.definition, "Contest definition id")->required();
  run_cmd->add_option("--workload", run.workloads, "Workload UUID or unique prefix");
  run_cmd->add_option("--workload-set", run.workload_set, "Repo-local workload set name");
  run_cmd->add_option("--cold-warmup-runs", run.cold_warmup_runs, "NVBench cold warmup runs before measurements")->check(CLI::NonNegativeNumber);
  auto* stopping_criterion_option = run_cmd
                                        ->add_option("--stopping-criterion", run.stopping_criterion, "NVBench stopping criterion")
                                        ->check(CLI::IsMember({"sample-count", "stdrel", "entropy"}));
  auto* min_samples_option = run_cmd->add_option("--min-samples", run.min_samples, "Minimum NVBench samples before criterion checks")->check(CLI::PositiveNumber);
  auto* target_samples_option = run_cmd->add_option("--target-samples", run.target_samples, "NVBench sample-count criterion target")->check(CLI::PositiveNumber);
  auto* max_noise_option = run_cmd->add_option("--max-noise", run.max_noise, "NVBench stdrel max relative standard deviation percentage")->check(CLI::PositiveNumber);
  auto* min_time_option = run_cmd->add_option("--min-time", run.min_time, "NVBench stdrel minimum accumulated measurement time in seconds")->check(CLI::PositiveNumber);
  run_cmd->add_option("--timeout", run.timeout, "NVBench timeout seconds");
  run_cmd->add_option("--devices", run.devices, "NVBench CUDA device id; currently limited to one device")->check(CLI::NonNegativeNumber);
  run_cmd->add_option("--json", run.json_output, "NVBench JSON output path");
  run_cmd->add_option("--csv", run.csv_output, "NVBench CSV output path");
  run_cmd->add_option("--markdown", run.markdown_output, "NVBench Markdown output path");
  run_cmd->add_flag("--dry-run", run.dry_run, "Write runtime context and print runner command without launching");
  run_cmd->callback([&] {
    const bool criterion_explicit = stopping_criterion_option->count() != 0;
    const bool min_samples_explicit = min_samples_option->count() != 0;
    const bool target_samples_explicit = target_samples_option->count() != 0;
    const bool max_noise_explicit = max_noise_option->count() != 0;
    const bool min_time_explicit = min_time_option->count() != 0;
    const bool has_stdrel_params = max_noise_explicit || min_time_explicit;
    const std::string effective_stopping_criterion =
        criterion_explicit ? run.stopping_criterion : (has_stdrel_params ? "stdrel" : "sample-count");
    if (has_stdrel_params && effective_stopping_criterion != "stdrel") {
      throw std::runtime_error("--max-noise and --min-time require the stdrel stopping criterion");
    }
    if (target_samples_explicit && effective_stopping_criterion != "sample-count") {
      throw std::runtime_error("--target-samples requires the sample-count stopping criterion");
    }

    const auto manifest_path = hp::manifest_path_for_artifact(run.artifact);
    if (!std::filesystem::is_regular_file(manifest_path)) {
      throw std::runtime_error("artifact is missing manifest.json; run build first");
    }
    const auto manifest = hp::read_manifest(manifest_path);
    if (!std::filesystem::is_regular_file(manifest.plugin_library)) {
      throw std::runtime_error("artifact is missing plugin library; run build first");
    }
    if (manifest.plugin_abi_version != HM_PROFILE_PLUGIN_ABI_VERSION) {
      throw std::runtime_error(fmt::format(
          "artifact plugin ABI version {} is unsupported; expected {}",
          manifest.plugin_abi_version,
          HM_PROFILE_PLUGIN_ABI_VERSION));
    }
    const auto runner_binary = run.runner_binary.empty() ? default_runner_binary() : run.runner_binary;
    if (!std::filesystem::is_regular_file(runner_binary)) {
      throw std::runtime_error(fmt::format(
          "static runner binary is missing at {}; configure cpp with -DHM_NVPROFILE_BUILD_STATIC_RUNNER=ON and rebuild, or pass --runner",
          runner_binary.string()));
    }

    auto selectors = run.workloads;
    if (!run.workload_set.empty()) {
      auto set_selectors = hp::load_workload_set_selectors(repo_root_from_cwd(), run.workload_set);
      selectors.insert(selectors.end(), set_selectors.begin(), set_selectors.end());
    }

    auto definition = hp::load_definition(run.dataset_root, run.definition);
    auto all_workloads = hp::load_workloads(run.dataset_root, run.definition);
    auto selected = hp::resolve_workload_selectors(all_workloads, selectors);
    std::vector<hp::RuntimeWorkload> runtime_workloads;
    runtime_workloads.reserve(selected.size());
    for (const auto& workload : selected) {
      runtime_workloads.push_back(hp::materialize_runtime_spec(definition, workload, run.dataset_root));
    }

    const auto context_path = run.artifact / "last-run-context.json";
    hp::write_runtime_context(context_path, definition, runtime_workloads, 0);

    std::vector<std::string> args;
    args.push_back(quote(runner_binary));
    args.push_back("--profile-plugin");
    args.push_back(quote(manifest.plugin_library));
    args.push_back("--profile-context");
    args.push_back(quote(context_path));
    args.push_back("--profile-device");
    args.push_back(std::to_string(run.devices));
    args.push_back("--devices");
    args.push_back(std::to_string(run.devices));
    args.push_back("--cold-warmup-runs");
    args.push_back(std::to_string(run.cold_warmup_runs));
    args.push_back("--stopping-criterion");
    args.push_back(effective_stopping_criterion);
    if (min_samples_explicit) {
      args.push_back("--min-samples");
      args.push_back(std::to_string(run.min_samples));
    }
    if (target_samples_explicit) {
      args.push_back("--target-samples");
      args.push_back(std::to_string(run.target_samples));
    }
    if (max_noise_explicit) {
      args.push_back("--max-noise");
      args.push_back(fmt::format("{}", run.max_noise));
    }
    if (min_time_explicit) {
      args.push_back("--min-time");
      args.push_back(fmt::format("{}", run.min_time));
    }
    args.push_back("--timeout");
    args.push_back(std::to_string(run.timeout));
    if (!run.json_output.empty()) {
      args.push_back("--json");
      args.push_back(quote(run.json_output));
    }
    if (!run.csv_output.empty()) {
      args.push_back("--csv");
      args.push_back(quote(run.csv_output));
    }
    if (!run.markdown_output.empty()) {
      args.push_back("--markdown");
      args.push_back(quote(run.markdown_output));
    }

    std::string command;
    for (const auto& arg : args) {
      if (!command.empty()) command += " ";
      command += arg;
    }
    std::cout << command << "\n";
    if (!run.dry_run) {
      run_command(command);
    }
  });

  CLI11_PARSE(app, argc, argv);
  return 0;
} catch (const std::exception& e) {
  std::cerr << "hm-nvbench-profile: " << e.what() << "\n";
  return 1;
}
