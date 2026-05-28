#include "hmdemo_nvbench_profile/plugin_abi.h"
#include "hmdemo_nvbench_profile/plugin_loader.hpp"

#include <cuda_runtime.h>
#include <dlpack/dlpack.h>
#include <nvbench/main.cuh>
#include <nvbench/nvbench.cuh>
#include <nlohmann/json.hpp>
#include <tvm/ffi/extra/c_env_api.h>

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

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
      if (ptr != nullptr) cudaFree(ptr);
      ptr = other.ptr;
      bytes = other.bytes;
      other.ptr = nullptr;
      other.bytes = 0;
    }
    return *this;
  }

  ~DeviceBuffer() {
    if (ptr != nullptr) cudaFree(ptr);
  }
};

struct TensorArg {
  std::string name;
  std::string dtype;
  std::vector<int64_t> shape;
  DeviceBuffer storage;
  DLTensor dl{};
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
std::unique_ptr<hmdemo::nvprofile::PluginLibrary> g_plugin;

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
  for (int i = 0; i < 8; ++i) {
    header_len |= static_cast<uint64_t>(static_cast<unsigned char>(data[i])) << (8 * i);
  }
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
  std::string plugin_path;
  bool saw_axis = false;

  for (size_t i = 1; i < args.size(); ++i) {
    if (args[i] == "--profile-context") {
      if (i + 1 >= args.size()) throw std::runtime_error("--profile-context requires a path");
      context_path = args[++i];
      continue;
    }
    if (args[i] == "--profile-plugin") {
      if (i + 1 >= args.size()) throw std::runtime_error("--profile-plugin requires a path");
      plugin_path = args[++i];
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
  if (plugin_path.empty()) throw std::runtime_error("--profile-plugin is required");
  cudaError_t err = cudaSetDevice(g_device);
  if (err != cudaSuccess) throw std::runtime_error(cudaGetErrorString(err));
  g_plugin = std::make_unique<hmdemo::nvprofile::PluginLibrary>(
      plugin_path,
      HM_PROFILE_PLUGIN_ADAPTER_TVM_FFI_MOE);
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
    if (!g_plugin) throw std::runtime_error("plugin is not loaded");
    TVMFFIStreamHandle old_stream = nullptr;
    TVMFFIEnvSetStream(kDLCUDA, g_device, launch.get_stream(), &old_stream);
    timer.start();
    const int status = g_plugin->moe().invoke(
        &workload.tensors.at("routing_logits").dl,
        &workload.tensors.at("routing_bias").dl,
        &workload.tensors.at("hidden_states").dl,
        &workload.tensors.at("hidden_states_scale").dl,
        &workload.tensors.at("gemm1_weights").dl,
        &workload.tensors.at("gemm1_weights_scale").dl,
        &workload.tensors.at("gemm2_weights").dl,
        &workload.tensors.at("gemm2_weights_scale").dl,
        workload.local_expert_offset,
        workload.routed_scaling_factor,
        &workload.tensors.at("output").dl);
    timer.stop();
    TVMFFIEnvSetStream(kDLCUDA, g_device, old_stream, nullptr);
    if (status != 0) {
      const auto last_error = g_plugin->moe().last_error == nullptr ? nullptr : g_plugin->moe().last_error();
      throw std::runtime_error(last_error == nullptr || last_error[0] == '\0' ? "plugin kernel failed" : last_error);
    }
  });
}

}  // namespace hm_profile_runner

NVBENCH_BENCH(hm_profile_runner::profile_moe)
    .set_name("profile_kernel")
    .add_int64_axis("workload_index", {0});

#define NVBENCH_MAIN_CUSTOM_ARGS_HANDLER(args) hm_profile_runner::strip_profile_args(args)
NVBENCH_MAIN
