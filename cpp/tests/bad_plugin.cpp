#include "hmdemo_nvbench_profile/plugin_abi.h"

extern "C" {

HM_PROFILE_PLUGIN_EXPORT int hm_profile_plugin_abi_version() {
#if defined(HM_NVPROFILE_BAD_PLUGIN_WRONG_ABI)
  return HM_PROFILE_PLUGIN_ABI_VERSION + 1;
#else
  return HM_PROFILE_PLUGIN_ABI_VERSION;
#endif
}

HM_PROFILE_PLUGIN_EXPORT const char* hm_profile_plugin_adapter() {
#if defined(HM_NVPROFILE_BAD_PLUGIN_WRONG_ADAPTER)
  return "wrong-adapter";
#else
  return HM_PROFILE_PLUGIN_ADAPTER_TVM_FFI_MOE;
#endif
}

HM_PROFILE_PLUGIN_EXPORT const char* hm_profile_plugin_last_error() {
  return "bad test plugin";
}

#if !defined(HM_NVPROFILE_BAD_PLUGIN_MISSING_ENTRY)
HM_PROFILE_PLUGIN_EXPORT int hm_profile_moe_kernel_v1(
    DLTensor*,
    DLTensor*,
    DLTensor*,
    DLTensor*,
    DLTensor*,
    DLTensor*,
    DLTensor*,
    DLTensor*,
    int64_t,
    double,
    DLTensor*) {
  return 0;
}
#endif

}  // extern "C"
