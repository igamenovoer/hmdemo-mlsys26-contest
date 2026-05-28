#include "hmdemo_nvbench_profile/plugin_loader.hpp"

#include <fmt/format.h>

#include <dlfcn.h>

#include <stdexcept>
#include <utility>

namespace hmdemo::nvprofile {
namespace {

void* checked_symbol(void* handle, const char* symbol, const std::filesystem::path& path) {
  dlerror();
  void* result = dlsym(handle, symbol);
  const char* error = dlerror();
  if (error != nullptr || result == nullptr) {
    throw std::runtime_error(fmt::format("plugin {} is missing required symbol {}: {}", path.string(), symbol, error ? error : "not found"));
  }
  return result;
}

MoePlugin resolve_plugin(void* handle, const std::filesystem::path& path, const std::string& expected_adapter) {
  auto abi_version = reinterpret_cast<hm_profile_plugin_abi_version_fn>(
      checked_symbol(handle, "hm_profile_plugin_abi_version", path));
  auto adapter = reinterpret_cast<hm_profile_plugin_adapter_fn>(
      checked_symbol(handle, "hm_profile_plugin_adapter", path));
  auto entry = reinterpret_cast<hm_profile_moe_kernel_v1_fn>(
      checked_symbol(handle, "hm_profile_moe_kernel_v1", path));
  auto last_error = reinterpret_cast<hm_profile_plugin_last_error_fn>(
      checked_symbol(handle, "hm_profile_plugin_last_error", path));

  const int version = abi_version();
  if (version != HM_PROFILE_PLUGIN_ABI_VERSION) {
    throw std::runtime_error(fmt::format(
        "plugin {} has unsupported ABI version {}; expected {}",
        path.string(),
        version,
        HM_PROFILE_PLUGIN_ABI_VERSION));
  }

  const std::string actual_adapter = adapter() == nullptr ? "" : adapter();
  if (actual_adapter != expected_adapter) {
    throw std::runtime_error(fmt::format(
        "plugin {} adapter mismatch: got '{}', expected '{}'",
        path.string(),
        actual_adapter,
        expected_adapter));
  }

  MoePlugin plugin;
  plugin.path = path;
  plugin.adapter = actual_adapter;
  plugin.invoke = entry;
  plugin.last_error = last_error;
  return plugin;
}

}  // namespace

PluginLibrary::PluginLibrary() = default;

PluginLibrary::PluginLibrary(std::filesystem::path path, std::string expected_adapter) {
  const auto path_text = path.string();
  handle_ = dlopen(path_text.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (handle_ == nullptr) {
    throw std::runtime_error(fmt::format("failed to load plugin {}: {}", path.string(), dlerror()));
  }
  try {
    plugin_ = resolve_plugin(handle_, path, expected_adapter);
  } catch (...) {
    dlclose(handle_);
    handle_ = nullptr;
    throw;
  }
}

PluginLibrary::~PluginLibrary() {
  if (handle_ != nullptr) {
    dlclose(handle_);
  }
}

PluginLibrary::PluginLibrary(PluginLibrary&& other) noexcept
    : handle_(std::exchange(other.handle_, nullptr)), plugin_(std::move(other.plugin_)) {}

PluginLibrary& PluginLibrary::operator=(PluginLibrary&& other) noexcept {
  if (this != &other) {
    if (handle_ != nullptr) {
      dlclose(handle_);
    }
    handle_ = std::exchange(other.handle_, nullptr);
    plugin_ = std::move(other.plugin_);
  }
  return *this;
}

}  // namespace hmdemo::nvprofile
