#include "hmdemo_nvbench_profile/artifact.hpp"

#include <fmt/format.h>
#include <nlohmann/json.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace hmdemo::nvprofile {
namespace {

std::string read_text(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    throw std::runtime_error(fmt::format("failed to read {}", path.string()));
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

void write_text(const std::filesystem::path& path, const std::string& text) {
  std::filesystem::create_directories(path.parent_path());
  std::ofstream stream(path, std::ios::binary);
  if (!stream) {
    throw std::runtime_error(fmt::format("failed to write {}", path.string()));
  }
  stream << text;
}

std::string fnv1a_hex(const std::string& text) {
  uint64_t hash = 14695981039346656037ull;
  for (unsigned char c : text) {
    hash ^= static_cast<uint64_t>(c);
    hash *= 1099511628211ull;
  }
  std::ostringstream out;
  out << std::hex << std::setw(16) << std::setfill('0') << hash;
  return out.str();
}

std::vector<std::string> path_strings(const std::vector<std::filesystem::path>& paths) {
  std::vector<std::string> out;
  out.reserve(paths.size());
  for (const auto& path : paths) {
    out.push_back(path.lexically_normal().string());
  }
  return out;
}

std::vector<std::filesystem::path> paths_from_json(const nlohmann::json& value) {
  std::vector<std::filesystem::path> out;
  for (const auto& item : value) {
    out.emplace_back(item.get<std::string>());
  }
  return out;
}

std::string shell_quote(const std::filesystem::path& path) {
  std::string text = path.string();
  std::string out = "'";
  for (char c : text) {
    if (c == '\'') {
      out += "'\\''";
    } else {
      out += c;
    }
  }
  out += "'";
  return out;
}

std::filesystem::path env_path(const char* name) {
  if (const char* value = std::getenv(name); value != nullptr && value[0] != '\0') {
    return std::filesystem::path(value);
  }
  return {};
}

bool looks_like_cuda_toolkit_root(const std::filesystem::path& root) {
  return !root.empty() && std::filesystem::is_regular_file(root / "include/cuda_runtime.h");
}

std::filesystem::path discover_cuda_toolkit_root() {
  for (const auto* name : {"CUDAToolkit_ROOT", "CUDA_HOME", "CUDA_PATH"}) {
    auto root = env_path(name);
    if (looks_like_cuda_toolkit_root(root)) return root;
  }
  auto conda_prefix = env_path("CONDA_PREFIX");
  if (!conda_prefix.empty()) {
    const auto lib = conda_prefix / "lib";
    if (std::filesystem::is_directory(lib)) {
      for (const auto& python_dir : std::filesystem::directory_iterator(lib)) {
        auto root = python_dir.path() / "site-packages/nvidia/cu13";
        if (looks_like_cuda_toolkit_root(root)) return root;
      }
    }
  }
  return {};
}

std::filesystem::path find_cudart(const std::filesystem::path& cuda_root) {
  for (const auto& candidate : {
           cuda_root / "lib64/libcudart.so",
           cuda_root / "lib64/libcudart.so.13",
           cuda_root / "lib/libcudart.so",
           cuda_root / "lib/libcudart.so.13",
       }) {
    if (std::filesystem::is_regular_file(candidate)) return candidate;
  }
  return {};
}

std::string join_cmake_list(const std::vector<std::filesystem::path>& paths) {
  std::string out;
  for (size_t i = 0; i < paths.size(); ++i) {
    if (i != 0) {
      out += ";";
    }
    out += paths[i].lexically_normal().string();
  }
  return out;
}

std::string join_flags(const std::vector<std::string>& flags) {
  std::string out;
  for (const auto& flag : flags) {
    out += " ";
    out += flag;
  }
  return out;
}

std::string render_runner_cmake(const ArtifactManifest& manifest) {
  return fmt::format(
      R"cmake(cmake_minimum_required(VERSION 3.30)
project(hm_nvbench_runner LANGUAGES CUDA CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CUDA_ARCHITECTURES "{cuda_arch}")

find_package(CUDAToolkit REQUIRED)
find_package(nlohmann_json REQUIRED)

set(NVBench_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set(NVBench_ENABLE_EXAMPLES OFF CACHE BOOL "" FORCE)
set(NVBench_ENABLE_CUPTI OFF CACHE BOOL "" FORCE)
set(NVBench_ENABLE_NVML ON CACHE BOOL "" FORCE)
add_subdirectory("{nvbench_source}" nvbench-build)

add_executable(hm-nvbench-runner runner.cu)
target_include_directories(hm-nvbench-runner PRIVATE
  "{artifact_src}"
  "{tvm_ffi_include}"
  "{tvm_ffi_dlpack}"
  {include_roots}
  {cutlass_include_roots}
)
target_compile_options(hm-nvbench-runner PRIVATE
  $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr {compiler_flags}>
)
target_link_libraries(hm-nvbench-runner PRIVATE
  nvbench::main
  nlohmann_json::nlohmann_json
  CUDA::cudart
)
)cmake",
      fmt::arg("cuda_arch", manifest.cuda_arch == "100a" ? "100a" : manifest.cuda_arch),
      fmt::arg("nvbench_source", manifest.nvbench_source.lexically_normal().string()),
      fmt::arg("artifact_src", (manifest.plugin_library.parent_path().parent_path() / "src").lexically_normal().string()),
      fmt::arg("tvm_ffi_include", (manifest.tvm_ffi_root / "include").lexically_normal().string()),
      fmt::arg("tvm_ffi_dlpack", (manifest.tvm_ffi_root / "3rdparty/dlpack/include").lexically_normal().string()),
      fmt::arg("include_roots", [&] {
        std::string result;
        for (const auto& root : manifest.include_roots) {
          result += "  \"" + root.lexically_normal().string() + "\"\n";
        }
        return result;
      }()),
      fmt::arg("cutlass_include_roots", [&] {
        std::string result;
        for (const auto& root : manifest.cutlass_include_roots) {
          result += "  \"" + root.lexically_normal().string() + "\"\n";
        }
        return result;
      }()),
      fmt::arg("compiler_flags", join_flags(manifest.compiler_flags)));
}

std::string render_runner_source(const ArtifactManifest& manifest) {
  (void)manifest;
  return R"cuda(
#include <cuda_runtime.h>
#include <dlpack/dlpack.h>
#include <nvbench/nvbench.cuh>
#include <nvbench/main.cuh>
#include <nlohmann/json.hpp>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/extra/c_env_api.h>

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include "kernel.cu"

namespace hm_profile_runner {

using json = nlohmann::json;

struct DeviceBuffer {
  void* ptr = nullptr;
  size_t bytes = 0;
  DeviceBuffer() = default;
  explicit DeviceBuffer(size_t nbytes) : bytes(nbytes) {
    if (bytes != 0) {
      cudaError_t err = cudaMalloc(&ptr, bytes);
      if (err != cudaSuccess) throw std::runtime_error(cudaGetErrorString(err));
    }
  }
  DeviceBuffer(const DeviceBuffer&) = delete;
  DeviceBuffer& operator=(const DeviceBuffer&) = delete;
  DeviceBuffer(DeviceBuffer&& other) noexcept : ptr(other.ptr), bytes(other.bytes) {
    other.ptr = nullptr;
    other.bytes = 0;
  }
  DeviceBuffer& operator=(DeviceBuffer&& other) noexcept {
    if (this != &other) {
      if (ptr) cudaFree(ptr);
      ptr = other.ptr;
      bytes = other.bytes;
      other.ptr = nullptr;
      other.bytes = 0;
    }
    return *this;
  }
  ~DeviceBuffer() {
    if (ptr) cudaFree(ptr);
  }
};

struct TensorArg {
  std::string name;
  std::string dtype;
  std::vector<int64_t> shape;
  DeviceBuffer storage;
  DLTensor dl{};
  tvm::ffi::TensorView view{&dl};
};

struct WorkloadState {
  std::string uuid;
  std::map<std::string, TensorArg> tensors;
  int64_t local_expert_offset = 0;
  double routed_scaling_factor = 1.0;
};

struct Context {
  std::vector<WorkloadState> workloads;
};

Context g_context;
int g_device = 0;

size_t dtype_bytes(const std::string& dtype) {
  if (dtype == "float32") return 4;
  if (dtype == "bfloat16") return 2;
  if (dtype == "float8_e4m3fn") return 1;
  if (dtype == "int32") return 4;
  throw std::runtime_error("unsupported dtype: " + dtype);
}

DLDataType dl_dtype(const std::string& dtype) {
  if (dtype == "float32") return DLDataType{kDLFloat, 32, 1};
  if (dtype == "bfloat16") return DLDataType{kDLBfloat, 16, 1};
  if (dtype == "float8_e4m3fn") return DLDataType{static_cast<uint8_t>(kDLFloat8_e4m3fn), 8, 1};
  if (dtype == "int32") return DLDataType{kDLInt, 32, 1};
  throw std::runtime_error("unsupported dtype: " + dtype);
}

size_t numel(const std::vector<int64_t>& shape) {
  size_t out = 1;
  for (int64_t dim : shape) out *= static_cast<size_t>(dim);
  return out;
}

std::vector<char> read_file(const std::string& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) throw std::runtime_error("failed to read " + path);
  stream.seekg(0, std::ios::end);
  auto size = stream.tellg();
  stream.seekg(0, std::ios::beg);
  std::vector<char> data(static_cast<size_t>(size));
  stream.read(data.data(), size);
  return data;
}

std::vector<char> read_safetensor(const std::string& path, const std::string& key) {
  auto data = read_file(path);
  if (data.size() < 8) throw std::runtime_error("invalid safetensors file");
  uint64_t header_len = 0;
  for (int i = 0; i < 8; ++i) header_len |= static_cast<uint64_t>(static_cast<unsigned char>(data[i])) << (8 * i);
  if (8 + header_len > data.size()) throw std::runtime_error("invalid safetensors header");
  auto header = json::parse(std::string(data.data() + 8, data.data() + 8 + header_len));
  auto offsets = header.at(key).at("data_offsets");
  size_t begin = offsets.at(0).get<size_t>();
  size_t end = offsets.at(1).get<size_t>();
  size_t payload_begin = 8 + static_cast<size_t>(header_len);
  if (payload_begin + end > data.size() || end < begin) throw std::runtime_error("invalid safetensors offsets");
  return std::vector<char>(data.begin() + static_cast<std::ptrdiff_t>(payload_begin + begin),
                           data.begin() + static_cast<std::ptrdiff_t>(payload_begin + end));
}

TensorArg make_tensor(const json& spec) {
  TensorArg arg;
  arg.name = spec.at("name").get<std::string>();
  arg.dtype = spec.at("dtype").get<std::string>();
  for (auto dim : spec.at("shape")) arg.shape.push_back(dim.get<int64_t>());
  arg.storage = DeviceBuffer(numel(arg.shape) * dtype_bytes(arg.dtype));

  const std::string kind = spec.value("input_type", "random");
  if (kind == "safetensors") {
    auto payload = read_safetensor(spec.at("path").get<std::string>(), spec.at("tensor_key").get<std::string>());
    if (payload.size() != arg.storage.bytes) throw std::runtime_error("safetensors payload size mismatch for " + arg.name);
    cudaMemcpy(arg.storage.ptr, payload.data(), payload.size(), cudaMemcpyHostToDevice);
  } else {
    const int fill = kind == "output" ? 0 : 17;
    cudaMemset(arg.storage.ptr, fill, arg.storage.bytes);
  }

  arg.dl.data = arg.storage.ptr;
  arg.dl.device = DLDevice{kDLCUDA, g_device};
  arg.dl.ndim = static_cast<int>(arg.shape.size());
  arg.dl.dtype = dl_dtype(arg.dtype);
  arg.dl.shape = arg.shape.data();
  arg.dl.strides = nullptr;
  arg.dl.byte_offset = 0;
  arg.view = tvm::ffi::TensorView(&arg.dl);
  return arg;
}

void load_context(const std::string& path) {
  auto root = json::parse(std::ifstream(path));
  g_context.workloads.clear();
  for (const auto& item : root.at("workloads")) {
    WorkloadState state;
    state.uuid = item.at("uuid").get<std::string>();
    for (const auto& input : item.at("inputs")) {
      if (input.value("input_type", "") == "scalar") {
        if (input.at("name").get<std::string>() == "local_expert_offset") {
          state.local_expert_offset = input.at("scalar_value").get<int64_t>();
        } else if (input.at("name").get<std::string>() == "routed_scaling_factor") {
          state.routed_scaling_factor = input.at("scalar_value").get<double>();
        }
        continue;
      }
      auto tensor = make_tensor(input);
      state.tensors.emplace(tensor.name, std::move(tensor));
    }
    for (auto output : item.at("outputs")) {
      output["input_type"] = "output";
      auto tensor = make_tensor(output);
      state.tensors.emplace(tensor.name, std::move(tensor));
    }
    g_context.workloads.push_back(std::move(state));
  }
}

void strip_profile_args(std::vector<std::string>& args) {
  std::vector<std::string> filtered;
  filtered.reserve(args.size());
  filtered.push_back(args.front());
  std::string context_path;
  bool saw_axis = false;
  for (size_t i = 1; i < args.size(); ++i) {
    if (args[i] == "--profile-context") {
      if (i + 1 >= args.size()) throw std::runtime_error("--profile-context requires a path");
      context_path = args[++i];
      continue;
    }
    if (args[i] == "--profile-device") {
      if (i + 1 >= args.size()) throw std::runtime_error("--profile-device requires a device id");
      g_device = std::stoi(args[++i]);
      continue;
    }
    if (args[i] == "--axis" || args[i] == "-a") saw_axis = true;
    filtered.push_back(args[i]);
  }
  if (context_path.empty()) throw std::runtime_error("--profile-context is required");
  cudaError_t err = cudaSetDevice(g_device);
  if (err != cudaSuccess) throw std::runtime_error(cudaGetErrorString(err));
  load_context(context_path);
  if (!saw_axis) {
    std::string values = "workload_index=[";
    for (size_t i = 0; i < g_context.workloads.size(); ++i) {
      if (i != 0) values += ",";
      values += std::to_string(i);
    }
    values += "]";
    filtered.push_back("--axis");
    filtered.push_back(values);
  }
  args.swap(filtered);
}

void profile_moe(nvbench::state& state) {
  const auto index = static_cast<size_t>(state.get_int64("workload_index"));
  if (index >= g_context.workloads.size()) state.skip("workload_index out of range");
  auto& workload = g_context.workloads[index];
  state.add_summary("workload_uuid").set_string("value", workload.uuid);

  state.exec(nvbench::exec_tag::timer, [&workload](nvbench::launch& launch, auto& timer) {
    TVMFFIStreamHandle old_stream = nullptr;
    TVMFFIEnvSetStream(kDLCUDA, g_device, launch.get_stream(), &old_stream);
    timer.start();
    moe_tvm_ffi::Kernel(
      workload.tensors.at("routing_logits").view,
      workload.tensors.at("routing_bias").view,
      workload.tensors.at("hidden_states").view,
      workload.tensors.at("hidden_states_scale").view,
      workload.tensors.at("gemm1_weights").view,
      workload.tensors.at("gemm1_weights_scale").view,
      workload.tensors.at("gemm2_weights").view,
      workload.tensors.at("gemm2_weights_scale").view,
      workload.local_expert_offset,
      workload.routed_scaling_factor,
      workload.tensors.at("output").view);
    timer.stop();
    TVMFFIEnvSetStream(kDLCUDA, g_device, old_stream, nullptr);
  });
}

}  // namespace hm_profile_runner

NVBENCH_BENCH(hm_profile_runner::profile_moe)
  .set_name("profile_kernel")
  .add_int64_axis("workload_index", {0});

#define NVBENCH_MAIN_CUSTOM_ARGS_HANDLER(args) hm_profile_runner::strip_profile_args(args)
NVBENCH_MAIN
)cuda";
}

std::string render_plugin_cmake(const ArtifactManifest& manifest) {
  const auto artifact_src = (manifest.plugin_library.parent_path().parent_path() / "src").lexically_normal();
  return fmt::format(
      R"cmake(cmake_minimum_required(VERSION 3.30)
project(hm_profile_kernel_plugin LANGUAGES CUDA CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CUDA_ARCHITECTURES "{cuda_arch}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${{CMAKE_BINARY_DIR}}")

find_package(CUDAToolkit REQUIRED)

add_library(hm_profile_kernel_plugin SHARED src/plugin.cu)
target_include_directories(hm_profile_kernel_plugin PRIVATE
  "{artifact_src}"
  "{profiler_include_root}"
  "{tvm_ffi_include}"
  "{tvm_ffi_dlpack}"
  {include_roots}
  {cutlass_include_roots}
)
target_compile_options(hm_profile_kernel_plugin PRIVATE
  $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr {compiler_flags}>
)
target_link_libraries(hm_profile_kernel_plugin PRIVATE CUDA::cudart)
)cmake",
      fmt::arg("cuda_arch", manifest.cuda_arch == "100a" ? "100a" : manifest.cuda_arch),
      fmt::arg("artifact_src", artifact_src.string()),
      fmt::arg("profiler_include_root", manifest.profiler_include_root.lexically_normal().string()),
      fmt::arg("tvm_ffi_include", (manifest.tvm_ffi_root / "include").lexically_normal().string()),
      fmt::arg("tvm_ffi_dlpack", (manifest.tvm_ffi_root / "3rdparty/dlpack/include").lexically_normal().string()),
      fmt::arg("include_roots", [&] {
        std::string result;
        for (const auto& root : manifest.include_roots) {
          result += "  \"" + root.lexically_normal().string() + "\"\n";
        }
        return result;
      }()),
      fmt::arg("cutlass_include_roots", [&] {
        std::string result;
        for (const auto& root : manifest.cutlass_include_roots) {
          result += "  \"" + root.lexically_normal().string() + "\"\n";
        }
        return result;
      }()),
      fmt::arg("compiler_flags", join_flags(manifest.compiler_flags)));
}

std::string render_plugin_source(const ArtifactManifest& manifest) {
  (void)manifest;
  return R"cuda(
#include <exception>
#include <string>

#include <tvm/ffi/container/tensor.h>

#include "hmdemo_nvbench_profile/plugin_abi.h"
#include "kernel.cu"

namespace {
thread_local std::string g_last_error;

tvm::ffi::TensorView view(DLTensor* tensor) {
  return tvm::ffi::TensorView(tensor);
}
}  // namespace

extern "C" {

HM_PROFILE_PLUGIN_EXPORT int hm_profile_plugin_abi_version() {
  return HM_PROFILE_PLUGIN_ABI_VERSION;
}

HM_PROFILE_PLUGIN_EXPORT const char* hm_profile_plugin_adapter() {
  return HM_PROFILE_PLUGIN_ADAPTER_TVM_FFI_MOE;
}

HM_PROFILE_PLUGIN_EXPORT const char* hm_profile_plugin_last_error() {
  return g_last_error.c_str();
}

HM_PROFILE_PLUGIN_EXPORT int hm_profile_moe_kernel_v1(
    DLTensor* routing_logits,
    DLTensor* routing_bias,
    DLTensor* hidden_states,
    DLTensor* hidden_states_scale,
    DLTensor* gemm1_weights,
    DLTensor* gemm1_weights_scale,
    DLTensor* gemm2_weights,
    DLTensor* gemm2_weights_scale,
    int64_t local_expert_offset,
    double routed_scaling_factor,
    DLTensor* output) {
  try {
    g_last_error.clear();
    moe_tvm_ffi::Kernel(
      view(routing_logits),
      view(routing_bias),
      view(hidden_states),
      view(hidden_states_scale),
      view(gemm1_weights),
      view(gemm1_weights_scale),
      view(gemm2_weights),
      view(gemm2_weights_scale),
      local_expert_offset,
      routed_scaling_factor,
      view(output));
    return 0;
  } catch (const std::exception& e) {
    g_last_error = e.what();
    return -1;
  } catch (...) {
    g_last_error = "unknown plugin exception";
    return -1;
  }
}

}  // extern "C"
)cuda";
}

void maybe_run(const std::string& command) {
  const int status = std::system(command.c_str());
  if (status != 0) {
    throw std::runtime_error(fmt::format("command failed with status {}: {}", status, command));
  }
}

}  // namespace

std::string file_hash(const std::filesystem::path& path) {
  return fnv1a_hex(read_text(path));
}

std::string string_hash(const std::string& text) {
  return fnv1a_hex(text);
}

std::vector<std::filesystem::path> split_paths(const std::string& value) {
  std::vector<std::filesystem::path> out;
  std::string current;
  for (char c : value) {
    if (c == ';' || c == ':') {
      if (!current.empty()) out.emplace_back(current);
      current.clear();
    } else {
      current.push_back(c);
    }
  }
  if (!current.empty()) out.emplace_back(current);
  return out;
}

ArtifactManifest make_manifest(const BuildOptions& options) {
  if (options.kernel.empty() || !std::filesystem::is_regular_file(options.kernel)) {
    throw std::runtime_error("kernel source does not exist: " + options.kernel.string());
  }
  ArtifactManifest manifest;
  manifest.adapter = options.adapter;
  manifest.definition = options.definition;
  manifest.cuda_arch = options.cuda_arch;
  manifest.build_type = options.build_type;
  manifest.kernel_source = std::filesystem::absolute(options.kernel).lexically_normal();
  manifest.kernel_sha = file_hash(manifest.kernel_source);
  manifest.cuda_toolkit_root = discover_cuda_toolkit_root();
  manifest.profiler_include_root = std::filesystem::absolute(options.repo_root / "cpp/include").lexically_normal();
  manifest.tvm_ffi_root = options.tvm_ffi_root.empty() ? std::filesystem::path{} : std::filesystem::absolute(options.tvm_ffi_root).lexically_normal();
  manifest.include_roots = options.include_roots;
  manifest.cutlass_include_roots = options.cutlass_include_roots;
  manifest.compiler_flags = options.compiler_flags;

  nlohmann::json identity = {
      {"profiler_version", manifest.profiler_version},
      {"adapter", manifest.adapter},
      {"definition", manifest.definition},
      {"cuda_arch", manifest.cuda_arch},
      {"build_type", manifest.build_type},
      {"kernel_source", manifest.kernel_source.string()},
      {"kernel_sha", manifest.kernel_sha},
      {"plugin_abi_version", manifest.plugin_abi_version},
      {"cuda_toolkit_root", manifest.cuda_toolkit_root.string()},
      {"profiler_include_root", manifest.profiler_include_root.string()},
      {"tvm_ffi_root", manifest.tvm_ffi_root.string()},
      {"include_roots", path_strings(manifest.include_roots)},
      {"cutlass_include_roots", path_strings(manifest.cutlass_include_roots)},
      {"compiler_flags", manifest.compiler_flags},
  };
  manifest.build_hash = string_hash(identity.dump());
  manifest.artifact_id = manifest.adapter + "-" + manifest.build_hash;
  return manifest;
}

nlohmann::json to_json(const ArtifactManifest& manifest) {
  return {
      {"manifest_version", manifest.manifest_version},
      {"profiler_version", manifest.profiler_version},
      {"artifact_id", manifest.artifact_id},
      {"build_hash", manifest.build_hash},
      {"adapter", manifest.adapter},
      {"definition", manifest.definition},
      {"cuda_arch", manifest.cuda_arch},
      {"build_type", manifest.build_type},
      {"kernel_source", manifest.kernel_source.string()},
      {"kernel_sha", manifest.kernel_sha},
      {"plugin_abi_version", manifest.plugin_abi_version},
      {"cuda_toolkit_root", manifest.cuda_toolkit_root.string()},
      {"profiler_include_root", manifest.profiler_include_root.string()},
      {"plugin_library", manifest.plugin_library.string()},
      {"tvm_ffi_root", manifest.tvm_ffi_root.string()},
      {"include_roots", path_strings(manifest.include_roots)},
      {"cutlass_include_roots", path_strings(manifest.cutlass_include_roots)},
      {"compiler_flags", manifest.compiler_flags},
  };
}

ArtifactManifest manifest_from_json(const nlohmann::json& value) {
  ArtifactManifest manifest;
  manifest.manifest_version = value.at("manifest_version").get<int>();
  manifest.profiler_version = value.at("profiler_version").get<std::string>();
  manifest.artifact_id = value.at("artifact_id").get<std::string>();
  manifest.build_hash = value.at("build_hash").get<std::string>();
  manifest.adapter = value.at("adapter").get<std::string>();
  manifest.definition = value.at("definition").get<std::string>();
  manifest.cuda_arch = value.at("cuda_arch").get<std::string>();
  manifest.build_type = value.at("build_type").get<std::string>();
  manifest.kernel_source = value.at("kernel_source").get<std::string>();
  manifest.kernel_sha = value.at("kernel_sha").get<std::string>();
  manifest.plugin_abi_version = value.value("plugin_abi_version", HM_PROFILE_PLUGIN_ABI_VERSION);
  manifest.cuda_toolkit_root = value.value("cuda_toolkit_root", std::string{});
  manifest.profiler_include_root = value.value("profiler_include_root", std::string{});
  manifest.plugin_library = value.at("plugin_library").get<std::string>();
  if (value.contains("nvbench_source")) {
    manifest.nvbench_source = value.at("nvbench_source").get<std::string>();
  }
  manifest.tvm_ffi_root = value.at("tvm_ffi_root").get<std::string>();
  manifest.include_roots = paths_from_json(value.at("include_roots"));
  manifest.cutlass_include_roots = paths_from_json(value.at("cutlass_include_roots"));
  manifest.compiler_flags = value.at("compiler_flags").get<std::vector<std::string>>();
  return manifest;
}

void write_manifest(const ArtifactManifest& manifest, const std::filesystem::path& path) {
  write_text(path, to_json(manifest).dump(2));
}

ArtifactManifest read_manifest(const std::filesystem::path& path) {
  return manifest_from_json(nlohmann::json::parse(read_text(path)));
}

bool manifest_matches_build(const ArtifactManifest& manifest, const BuildOptions& options) {
  auto expected = make_manifest(options);
  return manifest.build_hash == expected.build_hash && manifest.kernel_sha == expected.kernel_sha;
}

std::filesystem::path manifest_path_for_artifact(const std::filesystem::path& artifact_dir) {
  return artifact_dir / "manifest.json";
}

std::filesystem::path create_or_update_artifact(const BuildOptions& options) {
  auto manifest = make_manifest(options);
  const auto artifact_dir = std::filesystem::absolute(options.artifact_root / manifest.artifact_id).lexically_normal();
  const auto src_dir = artifact_dir / "src";
  const auto build_dir = artifact_dir / "build";
  std::filesystem::create_directories(src_dir);
  std::filesystem::create_directories(build_dir);
  manifest.plugin_library = build_dir / "libhm_profile_kernel_plugin.so";

  const auto manifest_path = manifest_path_for_artifact(artifact_dir);
  if (std::filesystem::exists(manifest_path) && !options.force) {
    auto existing = read_manifest(manifest_path);
    if (existing.build_hash == manifest.build_hash &&
        (options.skip_compile || std::filesystem::exists(existing.plugin_library))) {
      return artifact_dir;
    }
  }

  std::filesystem::copy_file(manifest.kernel_source, src_dir / "kernel.cu", std::filesystem::copy_options::overwrite_existing);
  write_text(src_dir / "plugin.cu", render_plugin_source(manifest));
  write_text(artifact_dir / "CMakeLists.txt", render_plugin_cmake(manifest));
  write_manifest(manifest, manifest_path);

  if (!options.skip_compile) {
    const auto conan_generators = options.repo_root / "cpp/build/Release/build/Release/generators";
    const auto prefix_arg = std::filesystem::is_directory(conan_generators)
                                ? fmt::format(" -DCMAKE_PREFIX_PATH={}", shell_quote(conan_generators))
                                : std::string{};
    const auto cuda_root = manifest.cuda_toolkit_root;
    const auto cuda_root_arg = looks_like_cuda_toolkit_root(cuda_root)
                                   ? fmt::format(" -DCUDAToolkit_ROOT={} -DCMAKE_CUDA_COMPILER={}",
                                                 shell_quote(cuda_root),
                                                 shell_quote(cuda_root / "bin/nvcc"))
                                   : std::string{};
    const auto cudart = find_cudart(cuda_root);
    const auto cudart_arg = !cudart.empty() ? fmt::format(" -DCUDA_CUDART={}", shell_quote(cudart)) : std::string{};
    const auto configure = fmt::format(
        "cmake -S {} -B {} -DCMAKE_BUILD_TYPE={}{}{}{}",
        shell_quote(artifact_dir),
        shell_quote(build_dir),
        options.build_type,
        prefix_arg,
        cuda_root_arg,
        cudart_arg);
    const auto build = fmt::format("cmake --build {} --target hm_profile_kernel_plugin", shell_quote(build_dir));
    maybe_run(configure);
    maybe_run(build);
  }
  return artifact_dir;
}

}  // namespace hmdemo::nvprofile
