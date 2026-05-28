#include "hmdemo_nvbench_profile/artifact.hpp"
#include "hmdemo_nvbench_profile/plugin_loader.hpp"
#include "hmdemo_nvbench_profile/trace.hpp"

#include <cassert>
#include <fstream>
#include <iostream>

int main() {
  using namespace hmdemo::nvprofile;

  const auto h1 = string_hash("kernel-a");
  const auto h2 = string_hash("kernel-b");
  assert(h1 != h2);

  Workload a;
  a.uuid = "abcdef00-0000-0000-0000-000000000000";
  Workload b;
  b.uuid = "abc99999-0000-0000-0000-000000000000";
  auto exact = resolve_workload_selectors({a, b}, {a.uuid});
  assert(exact.size() == 1);
  assert(exact.front().uuid == a.uuid);

  bool ambiguous = false;
  try {
    (void)resolve_workload_selectors({a, b}, {"abc"});
  } catch (const std::exception&) {
    ambiguous = true;
  }
  assert(ambiguous);

  auto expect_load_failure = [](const std::filesystem::path& path, const std::string& expected) {
    bool failed = false;
    try {
      PluginLibrary plugin(path);
    } catch (const std::exception& e) {
      failed = std::string(e.what()).find(expected) != std::string::npos;
    }
    assert(failed);
  };

  expect_load_failure("/definitely/missing/hm-profile-plugin.so", "failed to load plugin");
  expect_load_failure(HM_NVPROFILE_MISSING_ENTRY_PLUGIN_PATH, "hm_profile_moe_kernel_v1");
  expect_load_failure(HM_NVPROFILE_WRONG_ABI_PLUGIN_PATH, "unsupported ABI version");
  expect_load_failure(HM_NVPROFILE_WRONG_ADAPTER_PLUGIN_PATH, "adapter mismatch");

  std::cout << "smoke ok\n";
  return 0;
}
