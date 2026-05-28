#pragma once

#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace hmdemo::nvprofile {

struct TensorSpec {
  std::string name;
  std::vector<std::string> shape;
  std::string dtype;
  bool scalar = false;
};

struct Definition {
  std::string name;
  std::string op_type;
  std::map<std::string, int64_t> const_axes;
  std::vector<TensorSpec> inputs;
  std::vector<TensorSpec> outputs;
};

struct InputSpec {
  std::string type;
  std::string path;
  std::string tensor_key;
  nlohmann::json value;
};

struct Workload {
  std::string uuid;
  std::map<std::string, int64_t> axes;
  std::map<std::string, InputSpec> inputs;
};

struct MaterializedTensorSpec {
  std::string name;
  std::string dtype;
  std::vector<int64_t> shape;
  std::string input_type;
  std::string path;
  std::string tensor_key;
  nlohmann::json scalar_value;
};

struct RuntimeWorkload {
  std::string uuid;
  std::map<std::string, int64_t> axes;
  std::vector<MaterializedTensorSpec> inputs;
  std::vector<MaterializedTensorSpec> outputs;
};

Definition load_definition(const std::filesystem::path& dataset_root, const std::string& definition);
std::vector<Workload> load_workloads(const std::filesystem::path& dataset_root, const std::string& definition);
std::vector<Workload> resolve_workload_selectors(
    const std::vector<Workload>& workloads,
    const std::vector<std::string>& selectors);
std::vector<std::string> load_workload_set_selectors(
    const std::filesystem::path& repo_root,
    const std::string& set_name);
std::vector<int64_t> resolve_shape(
    const TensorSpec& spec,
    const Definition& definition,
    const Workload& workload);
RuntimeWorkload materialize_runtime_spec(
    const Definition& definition,
    const Workload& workload,
    const std::filesystem::path& dataset_root);
nlohmann::json runtime_context_json(
    const Definition& definition,
    const std::vector<RuntimeWorkload>& workloads,
    int random_seed);
void write_runtime_context(
    const std::filesystem::path& path,
    const Definition& definition,
    const std::vector<RuntimeWorkload>& workloads,
    int random_seed);

}  // namespace hmdemo::nvprofile
