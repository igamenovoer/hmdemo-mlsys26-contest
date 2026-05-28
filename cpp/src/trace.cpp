#include "hmdemo_nvbench_profile/trace.hpp"

#include <fmt/format.h>
#include <nlohmann/json.hpp>
#include <toml++/toml.hpp>

#include <fstream>
#include <set>
#include <sstream>
#include <stdexcept>

namespace hmdemo::nvprofile {
namespace {

using ordered_json = nlohmann::ordered_json;

std::string read_text(const std::filesystem::path& path) {
  std::ifstream stream(path);
  if (!stream) {
    throw std::runtime_error(fmt::format("failed to read {}", path.string()));
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

std::filesystem::path find_named_json(
    const std::filesystem::path& root,
    const std::string& subdir,
    const std::string& name) {
  const auto base = root / subdir;
  const auto target_name = name + ".json";
  if (!std::filesystem::exists(base)) {
    throw std::runtime_error(fmt::format("dataset directory does not exist: {}", base.string()));
  }
  for (const auto& entry : std::filesystem::recursive_directory_iterator(base)) {
    if (entry.is_regular_file() && entry.path().filename() == target_name) {
      return entry.path();
    }
  }
  throw std::runtime_error(fmt::format("definition JSON not found for {}", name));
}

std::filesystem::path find_named_jsonl(
    const std::filesystem::path& root,
    const std::string& subdir,
    const std::string& name) {
  const auto base = root / subdir;
  const auto target_name = name + ".jsonl";
  if (!std::filesystem::exists(base)) {
    throw std::runtime_error(fmt::format("dataset directory does not exist: {}", base.string()));
  }
  for (const auto& entry : std::filesystem::recursive_directory_iterator(base)) {
    if (entry.is_regular_file() && entry.path().filename() == target_name) {
      return entry.path();
    }
  }
  throw std::runtime_error(fmt::format("workload JSONL not found for {}", name));
}

TensorSpec tensor_spec_from_json(const std::string& name, const ordered_json& value) {
  TensorSpec spec;
  spec.name = name;
  spec.dtype = value.at("dtype").get<std::string>();
  if (value.at("shape").is_null()) {
    spec.scalar = true;
    return spec;
  }
  for (const auto& dim : value.at("shape")) {
    spec.shape.push_back(dim.get<std::string>());
  }
  return spec;
}

MaterializedTensorSpec materialized_from_spec(
    const TensorSpec& spec,
    const Definition& definition,
    const Workload& workload,
    const std::filesystem::path& dataset_root) {
  MaterializedTensorSpec out;
  out.name = spec.name;
  out.dtype = spec.dtype;
  out.shape = resolve_shape(spec, definition, workload);
  auto input = workload.inputs.find(spec.name);
  if (input == workload.inputs.end()) {
    out.input_type = spec.scalar ? "scalar" : "random";
    return out;
  }
  out.input_type = input->second.type;
  out.tensor_key = input->second.tensor_key;
  out.scalar_value = input->second.value;
  if (!input->second.path.empty()) {
    auto path = std::filesystem::path(input->second.path);
    if (path.is_relative()) {
      path = dataset_root / path;
    }
    out.path = std::filesystem::absolute(path).lexically_normal().string();
  }
  return out;
}

}  // namespace

Definition load_definition(const std::filesystem::path& dataset_root, const std::string& definition) {
  const auto path = find_named_json(dataset_root, "definitions", definition);
  const auto doc = ordered_json::parse(read_text(path));
  Definition out;
  out.name = doc.at("name").get<std::string>();
  out.op_type = doc.value("op_type", "");
  for (const auto& item : doc.at("axes").items()) {
    const auto& axis = item.value();
    if (axis.value("type", "") == "const") {
      out.const_axes[item.key()] = axis.at("value").get<int64_t>();
    }
  }
  for (const auto& item : doc.at("inputs").items()) {
    out.inputs.push_back(tensor_spec_from_json(item.key(), item.value()));
  }
  for (const auto& item : doc.at("outputs").items()) {
    out.outputs.push_back(tensor_spec_from_json(item.key(), item.value()));
  }
  return out;
}

std::vector<Workload> load_workloads(const std::filesystem::path& dataset_root, const std::string& definition) {
  const auto path = find_named_jsonl(dataset_root, "workloads", definition);
  std::ifstream stream(path);
  if (!stream) {
    throw std::runtime_error(fmt::format("failed to read {}", path.string()));
  }
  std::vector<Workload> out;
  std::string line;
  while (std::getline(stream, line)) {
    if (line.empty()) continue;
    const auto record = nlohmann::json::parse(line);
    const auto& wl = record.at("workload");
    Workload workload;
    workload.uuid = wl.at("uuid").get<std::string>();
    for (const auto& axis : wl.at("axes").items()) {
      workload.axes[axis.key()] = axis.value().get<int64_t>();
    }
    for (const auto& item : wl.at("inputs").items()) {
      InputSpec spec;
      spec.type = item.value().at("type").get<std::string>();
      spec.path = item.value().value("path", "");
      spec.tensor_key = item.value().value("tensor_key", "");
      if (item.value().contains("value")) {
        spec.value = item.value().at("value");
      }
      workload.inputs[item.key()] = spec;
    }
    out.push_back(std::move(workload));
  }
  return out;
}

std::vector<Workload> resolve_workload_selectors(
    const std::vector<Workload>& workloads,
    const std::vector<std::string>& selectors) {
  if (selectors.empty()) {
    return workloads;
  }

  std::vector<Workload> resolved;
  std::set<std::string> seen;
  for (const auto& selector : selectors) {
    std::vector<const Workload*> matches;
    for (const auto& workload : workloads) {
      if (workload.uuid == selector || workload.uuid.rfind(selector, 0) == 0) {
        matches.push_back(&workload);
      }
    }
    if (matches.empty()) {
      throw std::runtime_error(fmt::format("no workload matches selector {}", selector));
    }
    if (matches.size() > 1) {
      throw std::runtime_error(fmt::format("workload selector {} is ambiguous", selector));
    }
    if (seen.insert(matches.front()->uuid).second) {
      resolved.push_back(*matches.front());
    }
  }
  return resolved;
}

std::vector<std::string> load_workload_set_selectors(
    const std::filesystem::path& repo_root,
    const std::string& set_name) {
  const auto config_path = repo_root / "configs/workloads.toml";
  auto doc = toml::parse_file(config_path.string());
  auto sets = doc["sets"];
  auto set = sets[set_name];
  if (!set) {
    throw std::runtime_error(fmt::format("unknown workload set {}", set_name));
  }
  std::vector<std::string> out;
  auto arr = set["workloads"].as_array();
  if (!arr) {
    throw std::runtime_error(fmt::format("workload set {} has no workloads array", set_name));
  }
  for (auto&& item : *arr) {
    if (auto value = item.value<std::string>()) {
      out.push_back(*value);
    }
  }
  return out;
}

std::vector<int64_t> resolve_shape(
    const TensorSpec& spec,
    const Definition& definition,
    const Workload& workload) {
  std::vector<int64_t> out;
  if (spec.scalar) {
    return out;
  }
  for (const auto& axis_name : spec.shape) {
    auto workload_axis = workload.axes.find(axis_name);
    if (workload_axis != workload.axes.end()) {
      out.push_back(workload_axis->second);
      continue;
    }
    auto const_axis = definition.const_axes.find(axis_name);
    if (const_axis != definition.const_axes.end()) {
      out.push_back(const_axis->second);
      continue;
    }
    throw std::runtime_error(fmt::format("unresolved axis {} for tensor {}", axis_name, spec.name));
  }
  return out;
}

RuntimeWorkload materialize_runtime_spec(
    const Definition& definition,
    const Workload& workload,
    const std::filesystem::path& dataset_root) {
  RuntimeWorkload out;
  out.uuid = workload.uuid;
  out.axes = workload.axes;
  for (const auto& input : definition.inputs) {
    out.inputs.push_back(materialized_from_spec(input, definition, workload, dataset_root));
  }
  for (const auto& output : definition.outputs) {
    MaterializedTensorSpec item;
    item.name = output.name;
    item.dtype = output.dtype;
    item.shape = resolve_shape(output, definition, workload);
    item.input_type = "output";
    out.outputs.push_back(std::move(item));
  }
  return out;
}

nlohmann::json runtime_context_json(
    const Definition& definition,
    const std::vector<RuntimeWorkload>& workloads,
    int random_seed) {
  nlohmann::json root;
  root["definition"] = definition.name;
  root["adapter"] = "tvm-ffi-moe";
  root["random_seed"] = random_seed;
  root["workloads"] = nlohmann::json::array();
  for (const auto& workload : workloads) {
    nlohmann::json item;
    item["uuid"] = workload.uuid;
    item["axes"] = workload.axes;
    item["inputs"] = nlohmann::json::array();
    item["outputs"] = nlohmann::json::array();
    auto append = [](nlohmann::json& arr, const MaterializedTensorSpec& spec) {
      arr.push_back({
          {"name", spec.name},
          {"dtype", spec.dtype},
          {"shape", spec.shape},
          {"input_type", spec.input_type},
          {"path", spec.path},
          {"tensor_key", spec.tensor_key},
          {"scalar_value", spec.scalar_value},
      });
    };
    for (const auto& input : workload.inputs) append(item["inputs"], input);
    for (const auto& output : workload.outputs) append(item["outputs"], output);
    root["workloads"].push_back(std::move(item));
  }
  return root;
}

void write_runtime_context(
    const std::filesystem::path& path,
    const Definition& definition,
    const std::vector<RuntimeWorkload>& workloads,
    int random_seed) {
  std::filesystem::create_directories(path.parent_path());
  std::ofstream stream(path);
  if (!stream) {
    throw std::runtime_error(fmt::format("failed to write {}", path.string()));
  }
  stream << runtime_context_json(definition, workloads, random_seed).dump(2);
}

}  // namespace hmdemo::nvprofile
