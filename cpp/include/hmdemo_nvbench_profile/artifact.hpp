#pragma once

#include <filesystem>
#include <map>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace hmdemo::nvprofile {

struct BuildOptions {
  std::filesystem::path repo_root;
  std::filesystem::path kernel;
  std::string adapter = "tvm-ffi-moe";
  std::string definition;
  std::string cuda_arch = HM_NVPROFILE_DEFAULT_CUDA_ARCH;
  std::string build_type = "Release";
  std::filesystem::path artifact_root = HM_NVPROFILE_DEFAULT_ARTIFACT_ROOT;
  std::filesystem::path nvbench_source = HM_NVPROFILE_DEFAULT_NVBENCH_SOURCE;
  std::filesystem::path tvm_ffi_root = HM_NVPROFILE_DEFAULT_TVM_FFI_ROOT;
  std::vector<std::filesystem::path> include_roots;
  std::vector<std::filesystem::path> cutlass_include_roots;
  std::vector<std::string> compiler_flags;
  bool skip_compile = false;
  bool force = false;
};

struct ArtifactManifest {
  int manifest_version = 1;
  std::string profiler_version = HM_NVPROFILE_VERSION;
  std::string artifact_id;
  std::string build_hash;
  std::string adapter;
  std::string definition;
  std::string cuda_arch;
  std::string build_type;
  std::filesystem::path kernel_source;
  std::string kernel_sha;
  std::filesystem::path runner_binary;
  std::filesystem::path nvbench_source;
  std::filesystem::path tvm_ffi_root;
  std::vector<std::filesystem::path> include_roots;
  std::vector<std::filesystem::path> cutlass_include_roots;
  std::vector<std::string> compiler_flags;
};

std::string file_hash(const std::filesystem::path& path);
std::string string_hash(const std::string& text);
std::vector<std::filesystem::path> split_paths(const std::string& value);
ArtifactManifest make_manifest(const BuildOptions& options);
nlohmann::json to_json(const ArtifactManifest& manifest);
ArtifactManifest manifest_from_json(const nlohmann::json& value);
void write_manifest(const ArtifactManifest& manifest, const std::filesystem::path& path);
ArtifactManifest read_manifest(const std::filesystem::path& path);
bool manifest_matches_build(const ArtifactManifest& manifest, const BuildOptions& options);
std::filesystem::path create_or_update_artifact(const BuildOptions& options);
std::filesystem::path manifest_path_for_artifact(const std::filesystem::path& artifact_dir);

}  // namespace hmdemo::nvprofile
