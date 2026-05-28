#include "hmdemo_nvbench_profile/artifact.hpp"
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

  std::cout << "smoke ok\n";
  return 0;
}
