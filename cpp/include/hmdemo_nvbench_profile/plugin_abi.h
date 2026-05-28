#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DLTensor DLTensor;

#define HM_PROFILE_PLUGIN_ABI_VERSION 1
#define HM_PROFILE_PLUGIN_ADAPTER_TVM_FFI_MOE "tvm-ffi-moe"

#if defined(_WIN32)
#define HM_PROFILE_PLUGIN_EXPORT __declspec(dllexport)
#else
#define HM_PROFILE_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

typedef int (*hm_profile_plugin_abi_version_fn)(void);
typedef const char* (*hm_profile_plugin_adapter_fn)(void);
typedef const char* (*hm_profile_plugin_last_error_fn)(void);

typedef int (*hm_profile_moe_kernel_v1_fn)(
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
    DLTensor* output);

#ifdef __cplusplus
}  // extern "C"
#endif
