#pragma once

#include "hmdemo_nvbench_profile/plugin_abi.h"

#include <filesystem>
#include <memory>
#include <string>

namespace hmdemo::nvprofile {

struct MoePlugin {
  std::filesystem::path path;
  std::string adapter;
  hm_profile_moe_kernel_v1_fn invoke = nullptr;
  hm_profile_plugin_last_error_fn last_error = nullptr;
};

class PluginLibrary {
 public:
  PluginLibrary();
  explicit PluginLibrary(std::filesystem::path path, std::string expected_adapter = HM_PROFILE_PLUGIN_ADAPTER_TVM_FFI_MOE);
  ~PluginLibrary();

  PluginLibrary(const PluginLibrary&) = delete;
  PluginLibrary& operator=(const PluginLibrary&) = delete;
  PluginLibrary(PluginLibrary&& other) noexcept;
  PluginLibrary& operator=(PluginLibrary&& other) noexcept;

  [[nodiscard]] const MoePlugin& moe() const { return plugin_; }
  [[nodiscard]] explicit operator bool() const { return handle_ != nullptr; }

 private:
  void* handle_ = nullptr;
  MoePlugin plugin_;
};

}  // namespace hmdemo::nvprofile
