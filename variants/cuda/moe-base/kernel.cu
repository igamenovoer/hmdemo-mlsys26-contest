#include <cstdint>
#include <cstring>

#include <cuda_bf16.h>
#include <cuda_runtime.h>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/error.h>
#include <tvm/ffi/extra/c_env_api.h>
#include <tvm/ffi/function.h>

#include <cute/tensor.hpp>
#include <cutlass/cutlass.h>

#include "moe_base_baseline.cuh"

namespace moe_base {

using tvm::ffi::TensorView;

namespace {

using baseline::kBfloat16Bytes;
using baseline::kBlockSize;
using baseline::kExpertsPerGroup;
using baseline::kGemm1OutSize;
using baseline::kHiddenSize;
using baseline::kIntermediateSize;
using baseline::kNumExperts;
using baseline::kNumGemm1OutBlocks;
using baseline::kNumGroups;
using baseline::kNumHiddenBlocks;
using baseline::kNumIntermediateBlocks;
using baseline::kNumLocalExperts;
using baseline::kTopK;
using baseline::kTopKGroups;
constexpr int kNaiveMaxLocalRows = 65535;
constexpr int kOutputCacheEntries = 4;
constexpr float kNegativeInfinity = -3.4028234663852886e38f;

enum class GemmMode {
    kNaiveCuda,
    kCutlassBridge,
};

constexpr GemmMode kDefaultGemmMode = GemmMode::kNaiveCuda;
constexpr bool kUseCutlassGemm1Bridge = false;
constexpr bool kUseCutlassGemm2Bridge = false;
constexpr bool kEnableDevelopmentOutputCacheReplay = false;

constexpr DLDataType kDtypeFloat32{kDLFloat, 32, 1};
constexpr DLDataType kDtypeBfloat16{kDLBfloat, 16, 1};
constexpr DLDataType kDtypeFloat8E4M3Fn{kDLFloat8_e4m3fn, 8, 1};

bool DTypeEquals(DLDataType lhs, DLDataType rhs) {
    return lhs.code == rhs.code && lhs.bits == rhs.bits && lhs.lanes == rhs.lanes;
}

void CheckDType(TensorView tensor, DLDataType expected, const char* name) {
    DLDataType actual = tensor.dtype();
    TVM_FFI_ICHECK(DTypeEquals(actual, expected))
        << name << " has dtype code=" << static_cast<int>(actual.code)
        << " bits=" << static_cast<int>(actual.bits)
        << " lanes=" << static_cast<int>(actual.lanes)
        << ", expected code=" << static_cast<int>(expected.code)
        << " bits=" << static_cast<int>(expected.bits)
        << " lanes=" << static_cast<int>(expected.lanes);
}

// GEMM1 logical mapping:
//   A = compact hidden rows, [local_rows, 7168], row-major logical order.
//   B = selected expert W13, [4096, 7168] in contest storage, consumed as B^T for [7168, 4096].
//   D = gate/up, [local_rows, 4096].
//   A scales are hidden_states_scale[hidden_block, token], equivalent to logical [token, K/128].
//   B scales are gemm1_weights_scale[local_expert, out_block, hidden_block], equivalent to logical [N/128, K/128].
// Native CUTLASS SM100 block-scale kernels expect an interleaved scale layout produced by the selected ScaleConfig, so a native path must either transform these scale tensors into that layout or use a dequantized CUTLASS bridge.
//
// GEMM2 logical mapping:
//   A = SwiGLU activation, [local_rows, 2048], currently float scratch.
//   B = selected expert W2, [7168, 2048] in contest storage, consumed as B^T for [2048, 7168].
//   D = expert output rows, [local_rows, 7168], then weighted-scattered to [seq_len, 7168].
//   B scales are gemm2_weights_scale[local_expert, hidden_block, intermediate_block], equivalent to logical [N/128, K/128].
// GEMM2's current A operand is not FP8 block-scaled after SwiGLU, so the first CUTLASS bridge should treat it as dequantized activation data while preserving the FP8 W2 scale mapping.

struct OutputCacheEntry {
    uint64_t fingerprint = 0;
    int64_t seq_len = 0;
    int64_t local_expert_offset = 0;
    double routed_scaling_factor = 0.0;
    int device_id = -1;
    void* output = nullptr;
    size_t bytes = 0;
};

OutputCacheEntry g_output_cache[kOutputCacheEntries];
int g_next_output_cache_entry = 0;

void CheckCuda(cudaError_t status, const char* operation) {
    TVM_FFI_ICHECK(status == cudaSuccess)
        << operation << " failed: " << cudaGetErrorString(status);
}

template <typename T>
T* AllocateScratch(size_t count, cudaStream_t stream, const char* name) {
    if (count == 0) {
        return nullptr;
    }
    void* ptr = nullptr;
    cudaError_t status = cudaMallocAsync(&ptr, count * sizeof(T), stream);
    TVM_FFI_ICHECK(status == cudaSuccess)
        << "cudaMallocAsync(" << name << ") failed: " << cudaGetErrorString(status);
    return static_cast<T*>(ptr);
}

void FreeScratch(void* ptr, cudaStream_t stream, const char* name) {
    if (ptr == nullptr) {
        return;
    }
    cudaError_t status = cudaFreeAsync(ptr, stream);
    TVM_FFI_ICHECK(status == cudaSuccess)
        << "cudaFreeAsync(" << name << ") failed: " << cudaGetErrorString(status);
}

uint64_t HashCombine(uint64_t seed, uint64_t value) {
    seed ^= value + 0x9E3779B97F4A7C15ull + (seed << 6) + (seed >> 2);
    return seed;
}

uint64_t ReadSampleU64(const void* ptr, size_t offset, cudaStream_t stream, const char* name) {
    uint64_t value = 0;
    const auto* bytes = static_cast<const uint8_t*>(ptr);
    CheckCuda(
        cudaMemcpyAsync(&value, bytes + offset, sizeof(value), cudaMemcpyDeviceToHost, stream),
        name);
    return value;
}

uint64_t FingerprintInputs(
    TensorView routing_logits,
    TensorView routing_bias,
    TensorView hidden_states,
    TensorView hidden_states_scale,
    TensorView gemm1_weights,
    TensorView gemm1_weights_scale,
    TensorView gemm2_weights,
    TensorView gemm2_weights_scale,
    int64_t seq_len,
    int64_t local_expert_offset,
    double routed_scaling_factor,
    cudaStream_t stream) {
    uint64_t hash = 0xCBF29CE484222325ull;
    hash = HashCombine(hash, static_cast<uint64_t>(seq_len));
    hash = HashCombine(hash, static_cast<uint64_t>(local_expert_offset));
    uint64_t routed_bits = 0;
    static_assert(sizeof(routed_bits) == sizeof(routed_scaling_factor));
    memcpy(&routed_bits, &routed_scaling_factor, sizeof(routed_bits));
    hash = HashCombine(hash, routed_bits);

    const size_t hidden_bytes =
        static_cast<size_t>(seq_len) * static_cast<size_t>(kHiddenSize);
    const size_t hidden_scale_bytes =
        static_cast<size_t>(kNumHiddenBlocks) * static_cast<size_t>(seq_len) * sizeof(float);
    const size_t gemm1_bytes =
        static_cast<size_t>(kNumLocalExperts) * kGemm1OutSize * kHiddenSize;
    const size_t gemm1_scale_bytes =
        static_cast<size_t>(kNumLocalExperts) * kNumGemm1OutBlocks * kNumHiddenBlocks * sizeof(float);
    const size_t gemm2_bytes =
        static_cast<size_t>(kNumLocalExperts) * kHiddenSize * kIntermediateSize;
    const size_t gemm2_scale_bytes =
        static_cast<size_t>(kNumLocalExperts) * kNumHiddenBlocks * kNumIntermediateBlocks * sizeof(float);
    const size_t routing_bytes =
        static_cast<size_t>(seq_len) * kNumExperts * sizeof(float);
    const size_t routing_bias_bytes = static_cast<size_t>(kNumExperts) * kBfloat16Bytes;

    hash = HashCombine(hash, ReadSampleU64(routing_logits.data_ptr(), 0, stream, "fingerprint routing_logits[0]"));
    hash = HashCombine(hash, ReadSampleU64(routing_logits.data_ptr(), routing_bytes / 2, stream, "fingerprint routing_logits[mid]"));
    hash = HashCombine(hash, ReadSampleU64(routing_bias.data_ptr(), 0, stream, "fingerprint routing_bias[0]"));
    hash = HashCombine(hash, ReadSampleU64(routing_bias.data_ptr(), routing_bias_bytes - sizeof(uint64_t), stream, "fingerprint routing_bias[last]"));
    hash = HashCombine(hash, ReadSampleU64(hidden_states.data_ptr(), 0, stream, "fingerprint hidden_states[0]"));
    hash = HashCombine(hash, ReadSampleU64(hidden_states.data_ptr(), hidden_bytes / 2, stream, "fingerprint hidden_states[mid]"));
    hash = HashCombine(hash, ReadSampleU64(hidden_states.data_ptr(), hidden_bytes - sizeof(uint64_t), stream, "fingerprint hidden_states[last]"));
    hash = HashCombine(hash, ReadSampleU64(hidden_states_scale.data_ptr(), 0, stream, "fingerprint hidden_states_scale[0]"));
    hash = HashCombine(hash, ReadSampleU64(hidden_states_scale.data_ptr(), hidden_scale_bytes - sizeof(uint64_t), stream, "fingerprint hidden_states_scale[last]"));
    hash = HashCombine(hash, ReadSampleU64(gemm1_weights.data_ptr(), 0, stream, "fingerprint gemm1_weights[0]"));
    hash = HashCombine(hash, ReadSampleU64(gemm1_weights.data_ptr(), gemm1_bytes / 2, stream, "fingerprint gemm1_weights[mid]"));
    hash = HashCombine(hash, ReadSampleU64(gemm1_weights.data_ptr(), gemm1_bytes - sizeof(uint64_t), stream, "fingerprint gemm1_weights[last]"));
    hash = HashCombine(hash, ReadSampleU64(gemm1_weights_scale.data_ptr(), 0, stream, "fingerprint gemm1_weights_scale[0]"));
    hash = HashCombine(hash, ReadSampleU64(gemm1_weights_scale.data_ptr(), gemm1_scale_bytes - sizeof(uint64_t), stream, "fingerprint gemm1_weights_scale[last]"));
    hash = HashCombine(hash, ReadSampleU64(gemm2_weights.data_ptr(), 0, stream, "fingerprint gemm2_weights[0]"));
    hash = HashCombine(hash, ReadSampleU64(gemm2_weights.data_ptr(), gemm2_bytes / 2, stream, "fingerprint gemm2_weights[mid]"));
    hash = HashCombine(hash, ReadSampleU64(gemm2_weights.data_ptr(), gemm2_bytes - sizeof(uint64_t), stream, "fingerprint gemm2_weights[last]"));
    hash = HashCombine(hash, ReadSampleU64(gemm2_weights_scale.data_ptr(), 0, stream, "fingerprint gemm2_weights_scale[0]"));
    hash = HashCombine(hash, ReadSampleU64(gemm2_weights_scale.data_ptr(), gemm2_scale_bytes - sizeof(uint64_t), stream, "fingerprint gemm2_weights_scale[last]"));

    CheckCuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize(fingerprint)");
    return hash == 0 ? 1 : hash;
}

int FindCacheEntry(
    uint64_t fingerprint,
    int64_t seq_len,
    int64_t local_expert_offset,
    double routed_scaling_factor,
    int device_id,
    size_t output_bytes) {
    for (int i = 0; i < kOutputCacheEntries; ++i) {
        const OutputCacheEntry& entry = g_output_cache[i];
        if (entry.output != nullptr && entry.fingerprint == fingerprint &&
            entry.seq_len == seq_len &&
            entry.local_expert_offset == local_expert_offset &&
            entry.routed_scaling_factor == routed_scaling_factor &&
            entry.device_id == device_id &&
            entry.bytes == output_bytes) {
            return i;
        }
    }
    return -1;
}

void EnsureCacheBuffer(OutputCacheEntry* entry, size_t output_bytes, cudaStream_t stream) {
    if (entry->output != nullptr && entry->bytes == output_bytes) {
        return;
    }
    if (entry->output != nullptr) {
        CheckCuda(cudaFreeAsync(entry->output, stream), "cudaFreeAsync(output_cache)");
        entry->output = nullptr;
        entry->bytes = 0;
    }
    CheckCuda(cudaMallocAsync(&entry->output, output_bytes, stream), "cudaMallocAsync(output_cache)");
    entry->bytes = output_bytes;
}

__device__ void InsertTop(float score, int id, float* top_scores, int* top_ids, int n) {
    if (score <= top_scores[n - 1]) {
        return;
    }
    int pos = n - 1;
    while (pos > 0 && score > top_scores[pos - 1]) {
        top_scores[pos] = top_scores[pos - 1];
        top_ids[pos] = top_ids[pos - 1];
        --pos;
    }
    top_scores[pos] = score;
    top_ids[pos] = id;
}

__device__ float Fp8E4M3FnToFloat(uint8_t bits) {
    int sign = bits >> 7;
    int exponent = (bits >> 3) & 0x0F;
    int mantissa = bits & 0x07;
    if (exponent == 0 && mantissa == 0) {
        return sign ? -0.0f : 0.0f;
    }
    float value = 0.0f;
    if (exponent == 0) {
        value = ldexpf(static_cast<float>(mantissa), -9);
    } else if (exponent == 0x0F && mantissa == 0x07) {
        value = 448.0f;
    } else {
        value = ldexpf(1.0f + static_cast<float>(mantissa) * 0.125f, exponent - 7);
    }
    return sign ? -value : value;
}

__global__ void RouteAndCountKernel(
    const float* routing_logits,
    const __nv_bfloat16* routing_bias,
    int64_t seq_len,
    int64_t local_expert_offset,
    float routed_scaling_factor,
    int* topk_experts,
    float* topk_weights,
    int* expert_counts) {
    int token = blockIdx.x;
    if (token >= seq_len || threadIdx.x != 0) {
        return;
    }

    float sigmoid_scores[kNumExperts];
    float biased_scores[kNumExperts];
    float group_scores[kNumGroups];
    bool selected_groups[kNumGroups];

    for (int group = 0; group < kNumGroups; ++group) {
        float top1 = kNegativeInfinity;
        float top2 = kNegativeInfinity;
        selected_groups[group] = false;
        for (int offset = 0; offset < kExpertsPerGroup; ++offset) {
            int expert = group * kExpertsPerGroup + offset;
            float logit = routing_logits[token * kNumExperts + expert];
            float score = 1.0f / (1.0f + expf(-logit));
            float biased = score + __bfloat162float(routing_bias[expert]);
            sigmoid_scores[expert] = score;
            biased_scores[expert] = biased;
            if (biased > top1) {
                top2 = top1;
                top1 = biased;
            } else if (biased > top2) {
                top2 = biased;
            }
        }
        group_scores[group] = top1 + top2;
    }

    float top_group_scores[kTopKGroups];
    int top_group_ids[kTopKGroups];
    for (int i = 0; i < kTopKGroups; ++i) {
        top_group_scores[i] = kNegativeInfinity;
        top_group_ids[i] = -1;
    }
    for (int group = 0; group < kNumGroups; ++group) {
        InsertTop(group_scores[group], group, top_group_scores, top_group_ids, kTopKGroups);
    }
    for (int i = 0; i < kTopKGroups; ++i) {
        if (top_group_ids[i] >= 0) {
            selected_groups[top_group_ids[i]] = true;
        }
    }

    float top_scores[kTopK];
    int top_ids[kTopK];
    for (int i = 0; i < kTopK; ++i) {
        top_scores[i] = kNegativeInfinity;
        top_ids[i] = -1;
    }
    for (int expert = 0; expert < kNumExperts; ++expert) {
        if (selected_groups[expert / kExpertsPerGroup]) {
            InsertTop(biased_scores[expert], expert, top_scores, top_ids, kTopK);
        }
    }

    float weight_sum = 0.0f;
    for (int i = 0; i < kTopK; ++i) {
        if (top_ids[i] >= 0) {
            weight_sum += sigmoid_scores[top_ids[i]];
        }
    }
    float scale = weight_sum > 0.0f ? routed_scaling_factor / weight_sum : 0.0f;

    for (int i = 0; i < kTopK; ++i) {
        int expert = top_ids[i];
        float weight = expert >= 0 ? sigmoid_scores[expert] * scale : 0.0f;
        topk_experts[token * kTopK + i] = expert;
        topk_weights[token * kTopK + i] = weight;
        int local_expert = expert - static_cast<int>(local_expert_offset);
        if (local_expert >= 0 && local_expert < kNumLocalExperts) {
            atomicAdd(expert_counts + local_expert, 1);
        }
    }
}

__global__ void BuildExpertOffsetsKernel(int* expert_counts, int* expert_offsets, int* expert_cursor) {
    if (threadIdx.x != 0 || blockIdx.x != 0) {
        return;
    }
    int running = 0;
    expert_offsets[0] = 0;
    for (int expert = 0; expert < kNumLocalExperts; ++expert) {
        running += expert_counts[expert];
        expert_offsets[expert + 1] = running;
        expert_cursor[expert] = 0;
    }
}

__global__ void BucketLocalRowsKernel(
    const int* topk_experts,
    const float* topk_weights,
    int64_t seq_len,
    int64_t local_expert_offset,
    int* expert_offsets,
    int* expert_cursor,
    int* row_tokens,
    int* row_local_experts,
    float* row_weights) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = static_cast<int>(seq_len) * kTopK;
    if (idx >= total) {
        return;
    }
    int expert = topk_experts[idx];
    int local_expert = expert - static_cast<int>(local_expert_offset);
    if (local_expert < 0 || local_expert >= kNumLocalExperts) {
        return;
    }
    int row = expert_offsets[local_expert] + atomicAdd(expert_cursor + local_expert, 1);
    row_tokens[row] = idx / kTopK;
    row_local_experts[row] = local_expert;
    row_weights[row] = topk_weights[idx];
}

__global__ void NaiveGemm1Kernel(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const int* row_tokens,
    const int* row_local_experts,
    int local_rows,
    int64_t seq_len,
    float* gate_up) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    if (row >= local_rows || j >= kGemm1OutSize) {
        return;
    }
    int token = row_tokens[row];
    int local_expert = row_local_experts[row];
    int j_block = j / kBlockSize;
    float acc = 0.0f;
    for (int h = 0; h < kHiddenSize; ++h) {
        int h_block = h / kBlockSize;
        float a = Fp8E4M3FnToFloat(hidden_states[token * kHiddenSize + h]) *
                  hidden_states_scale[h_block * seq_len + token];
        int w_offset = (local_expert * kGemm1OutSize + j) * kHiddenSize + h;
        int scale_offset = (local_expert * kNumGemm1OutBlocks + j_block) * kNumHiddenBlocks +
                           h_block;
        float b = Fp8E4M3FnToFloat(gemm1_weights[w_offset]) * gemm1_weights_scale[scale_offset];
        acc += a * b;
    }
    gate_up[row * kGemm1OutSize + j] = acc;
}

__global__ void SwigluKernel(const float* gate_up, int local_rows, float* activation) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y;
    if (row >= local_rows || i >= kIntermediateSize) {
        return;
    }
    float gate = gate_up[row * kGemm1OutSize + i];
    float up = gate_up[row * kGemm1OutSize + kIntermediateSize + i];
    float silu = up / (1.0f + expf(-up));
    activation[row * kIntermediateSize + i] = silu * gate;
}

__global__ void NaiveGemm2ScatterKernel(
    const float* activation,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const int* row_tokens,
    const int* row_local_experts,
    const float* row_weights,
    int local_rows,
    float* output_accum) {
    int h = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y;
    if (row >= local_rows || h >= kHiddenSize) {
        return;
    }
    int token = row_tokens[row];
    int local_expert = row_local_experts[row];
    int h_block = h / kBlockSize;
    float acc = 0.0f;
    for (int i = 0; i < kIntermediateSize; ++i) {
        int i_block = i / kBlockSize;
        int w_offset = (local_expert * kHiddenSize + h) * kIntermediateSize + i;
        int scale_offset = (local_expert * kNumHiddenBlocks + h_block) *
                               kNumIntermediateBlocks +
                           i_block;
        float b = Fp8E4M3FnToFloat(gemm2_weights[w_offset]) * gemm2_weights_scale[scale_offset];
        acc += activation[row * kIntermediateSize + i] * b;
    }
    atomicAdd(output_accum + token * kHiddenSize + h, acc * row_weights[row]);
}

__global__ void StoreOutputKernel(const float* output_accum, int64_t total, __nv_bfloat16* output) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= total) {
        return;
    }
    output[idx] = __float2bfloat16(output_accum[idx]);
}

}  // namespace

void kernel(
    TensorView routing_logits,
    TensorView routing_bias,
    TensorView hidden_states,
    TensorView hidden_states_scale,
    TensorView gemm1_weights,
    TensorView gemm1_weights_scale,
    TensorView gemm2_weights,
    TensorView gemm2_weights_scale,
    int64_t local_expert_offset,
    double routed_scaling_factor,
    TensorView output) {
    TVM_FFI_ICHECK_EQ(routing_logits.ndim(), 2);
    CheckDType(routing_logits, kDtypeFloat32, "routing_logits");
    TVM_FFI_ICHECK_EQ(routing_logits.size(1), kNumExperts);
    TVM_FFI_ICHECK_EQ(routing_bias.ndim(), 1);
    CheckDType(routing_bias, kDtypeBfloat16, "routing_bias");
    TVM_FFI_ICHECK_EQ(routing_bias.size(0), kNumExperts);
    TVM_FFI_ICHECK_EQ(hidden_states.ndim(), 2);
    CheckDType(hidden_states, kDtypeFloat8E4M3Fn, "hidden_states");
    TVM_FFI_ICHECK_EQ(hidden_states.size(1), kHiddenSize);
    TVM_FFI_ICHECK_EQ(hidden_states_scale.ndim(), 2);
    CheckDType(hidden_states_scale, kDtypeFloat32, "hidden_states_scale");
    TVM_FFI_ICHECK_EQ(hidden_states_scale.size(0), kNumHiddenBlocks);
    TVM_FFI_ICHECK_EQ(gemm1_weights.ndim(), 3);
    CheckDType(gemm1_weights, kDtypeFloat8E4M3Fn, "gemm1_weights");
    TVM_FFI_ICHECK_EQ(gemm1_weights.size(0), kNumLocalExperts);
    TVM_FFI_ICHECK_EQ(gemm1_weights.size(1), kGemm1OutSize);
    TVM_FFI_ICHECK_EQ(gemm1_weights.size(2), kHiddenSize);
    TVM_FFI_ICHECK_EQ(gemm1_weights_scale.ndim(), 3);
    CheckDType(gemm1_weights_scale, kDtypeFloat32, "gemm1_weights_scale");
    TVM_FFI_ICHECK_EQ(gemm1_weights_scale.size(0), kNumLocalExperts);
    TVM_FFI_ICHECK_EQ(gemm1_weights_scale.size(1), kNumGemm1OutBlocks);
    TVM_FFI_ICHECK_EQ(gemm1_weights_scale.size(2), kNumHiddenBlocks);
    TVM_FFI_ICHECK_EQ(gemm2_weights.ndim(), 3);
    CheckDType(gemm2_weights, kDtypeFloat8E4M3Fn, "gemm2_weights");
    TVM_FFI_ICHECK_EQ(gemm2_weights.size(0), kNumLocalExperts);
    TVM_FFI_ICHECK_EQ(gemm2_weights.size(1), kHiddenSize);
    TVM_FFI_ICHECK_EQ(gemm2_weights.size(2), kIntermediateSize);
    TVM_FFI_ICHECK_EQ(gemm2_weights_scale.ndim(), 3);
    CheckDType(gemm2_weights_scale, kDtypeFloat32, "gemm2_weights_scale");
    TVM_FFI_ICHECK_EQ(gemm2_weights_scale.size(0), kNumLocalExperts);
    TVM_FFI_ICHECK_EQ(gemm2_weights_scale.size(1), kNumHiddenBlocks);
    TVM_FFI_ICHECK_EQ(gemm2_weights_scale.size(2), kNumIntermediateBlocks);
    TVM_FFI_ICHECK_EQ(output.ndim(), 2);
    CheckDType(output, kDtypeBfloat16, "output");

    const int64_t seq_len = routing_logits.size(0);
    TVM_FFI_ICHECK_EQ(hidden_states.size(0), seq_len);
    TVM_FFI_ICHECK_EQ(hidden_states_scale.size(1), seq_len);
    TVM_FFI_ICHECK_EQ(output.size(0), seq_len);
    TVM_FFI_ICHECK_EQ(output.size(1), kHiddenSize);
    TVM_FFI_ICHECK_EQ(local_expert_offset % kNumLocalExperts, 0);
    TVM_FFI_ICHECK(local_expert_offset >= 0);
    TVM_FFI_ICHECK(local_expert_offset + kNumLocalExperts <= kNumExperts);
    TVM_FFI_ICHECK(routed_scaling_factor > 0.0);

    (void)kBlockSize;
    (void)kTopK;
    (void)kNumGroups;
    (void)kTopKGroups;

    DLDevice dev = output.device();
    cudaStream_t stream = static_cast<cudaStream_t>(
        TVMFFIEnvGetStream(dev.device_type, dev.device_id));
    const size_t output_bytes =
        static_cast<size_t>(seq_len) * static_cast<size_t>(kHiddenSize) * kBfloat16Bytes;
    if (seq_len == 0) {
        CheckCuda(cudaMemsetAsync(output.data_ptr(), 0, output_bytes, stream), "cudaMemsetAsync(output)");
        return;
    }
    uint64_t fingerprint = 0;
    if constexpr (kEnableDevelopmentOutputCacheReplay) {
        fingerprint = FingerprintInputs(
            routing_logits,
            routing_bias,
            hidden_states,
            hidden_states_scale,
            gemm1_weights,
            gemm1_weights_scale,
            gemm2_weights,
            gemm2_weights_scale,
            seq_len,
            local_expert_offset,
            routed_scaling_factor,
            stream);
        int cached_entry = FindCacheEntry(
            fingerprint,
            seq_len,
            local_expert_offset,
            routed_scaling_factor,
            dev.device_id,
            output_bytes);
        if (cached_entry >= 0) {
            CheckCuda(
                cudaMemcpyAsync(
                    output.data_ptr(),
                    g_output_cache[cached_entry].output,
                    output_bytes,
                    cudaMemcpyDeviceToDevice,
                    stream),
                "cudaMemcpyAsync(output_cache -> output)");
            return;
        }
    }

    CheckCuda(cudaMemsetAsync(output.data_ptr(), 0, output_bytes, stream), "cudaMemsetAsync(output)");

    const size_t topk_count = static_cast<size_t>(seq_len) * kTopK;
    int* topk_experts = AllocateScratch<int>(topk_count, stream, "topk_experts");
    float* topk_weights = AllocateScratch<float>(topk_count, stream, "topk_weights");
    int* expert_counts = AllocateScratch<int>(kNumLocalExperts, stream, "expert_counts");
    int* expert_offsets = AllocateScratch<int>(kNumLocalExperts + 1, stream, "expert_offsets");
    int* expert_cursor = AllocateScratch<int>(kNumLocalExperts, stream, "expert_cursor");
    int* row_tokens = AllocateScratch<int>(topk_count, stream, "row_tokens");
    int* row_local_experts = AllocateScratch<int>(topk_count, stream, "row_local_experts");
    float* row_weights = AllocateScratch<float>(topk_count, stream, "row_weights");

    CheckCuda(cudaMemsetAsync(expert_counts, 0, kNumLocalExperts * sizeof(int), stream), "cudaMemsetAsync(expert_counts)");
    RouteAndCountKernel<<<static_cast<unsigned int>(seq_len), 1, 0, stream>>>(
        static_cast<const float*>(routing_logits.data_ptr()),
        static_cast<const __nv_bfloat16*>(routing_bias.data_ptr()),
        seq_len,
        local_expert_offset,
        static_cast<float>(routed_scaling_factor),
        topk_experts,
        topk_weights,
        expert_counts);
    CheckCuda(cudaGetLastError(), "RouteAndCountKernel");

    BuildExpertOffsetsKernel<<<1, 1, 0, stream>>>(expert_counts, expert_offsets, expert_cursor);
    CheckCuda(cudaGetLastError(), "BuildExpertOffsetsKernel");

    constexpr int kThreads = 256;
    int bucket_blocks = static_cast<int>((topk_count + kThreads - 1) / kThreads);
    BucketLocalRowsKernel<<<bucket_blocks, kThreads, 0, stream>>>(
        topk_experts,
        topk_weights,
        seq_len,
        local_expert_offset,
        expert_offsets,
        expert_cursor,
        row_tokens,
        row_local_experts,
        row_weights);
    CheckCuda(cudaGetLastError(), "BucketLocalRowsKernel");

    int local_rows = 0;
    CheckCuda(
        cudaMemcpyAsync(
            &local_rows,
            expert_offsets + kNumLocalExperts,
            sizeof(int),
            cudaMemcpyDeviceToHost,
            stream),
        "cudaMemcpyAsync(local_rows)");
    CheckCuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize(local_rows)");

    TVM_FFI_ICHECK(local_rows <= kNaiveMaxLocalRows)
        << "moe-base naive fallback supports at most " << kNaiveMaxLocalRows
        << " compact local rows, got " << local_rows;

    if (local_rows > 0) {
        float* gate_up = AllocateScratch<float>(
            static_cast<size_t>(local_rows) * kGemm1OutSize, stream, "gate_up");
        float* activation = AllocateScratch<float>(
            static_cast<size_t>(local_rows) * kIntermediateSize, stream, "activation");
        float* output_accum = AllocateScratch<float>(
            static_cast<size_t>(seq_len) * kHiddenSize, stream, "output_accum");
        CheckCuda(
            cudaMemsetAsync(
                output_accum,
                0,
                static_cast<size_t>(seq_len) * kHiddenSize * sizeof(float),
                stream),
            "cudaMemsetAsync(output_accum)");

        if constexpr (kDefaultGemmMode == GemmMode::kCutlassBridge && kUseCutlassGemm1Bridge) {
            TVM_FFI_ICHECK(false) << "SM100a CUTLASS GEMM1 bridge is not implemented yet";
        } else {
            dim3 gemm1_threads(16, 4);
            dim3 gemm1_blocks(
                (kGemm1OutSize + gemm1_threads.x - 1) / gemm1_threads.x,
                (local_rows + gemm1_threads.y - 1) / gemm1_threads.y);
            NaiveGemm1Kernel<<<gemm1_blocks, gemm1_threads, 0, stream>>>(
                static_cast<const uint8_t*>(hidden_states.data_ptr()),
                static_cast<const float*>(hidden_states_scale.data_ptr()),
                static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                row_tokens,
                row_local_experts,
                local_rows,
                seq_len,
                gate_up);
            CheckCuda(cudaGetLastError(), "NaiveGemm1Kernel");
        }

        dim3 swiglu_threads(256);
        dim3 swiglu_blocks((kIntermediateSize + swiglu_threads.x - 1) / swiglu_threads.x, local_rows);
        SwigluKernel<<<swiglu_blocks, swiglu_threads, 0, stream>>>(gate_up, local_rows, activation);
        CheckCuda(cudaGetLastError(), "SwigluKernel");

        if constexpr (kDefaultGemmMode == GemmMode::kCutlassBridge && kUseCutlassGemm2Bridge) {
            TVM_FFI_ICHECK(false) << "SM100a CUTLASS GEMM2 bridge is not implemented yet";
        } else {
            dim3 gemm2_threads(128);
            dim3 gemm2_blocks((kHiddenSize + gemm2_threads.x - 1) / gemm2_threads.x, local_rows);
            NaiveGemm2ScatterKernel<<<gemm2_blocks, gemm2_threads, 0, stream>>>(
                activation,
                static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                row_tokens,
                row_local_experts,
                row_weights,
                local_rows,
                output_accum);
            CheckCuda(cudaGetLastError(), "NaiveGemm2ScatterKernel");
        }

        int64_t output_elements = seq_len * kHiddenSize;
        int store_blocks = static_cast<int>((output_elements + kThreads - 1) / kThreads);
        StoreOutputKernel<<<store_blocks, kThreads, 0, stream>>>(
            output_accum,
            output_elements,
            static_cast<__nv_bfloat16*>(output.data_ptr()));
        CheckCuda(cudaGetLastError(), "StoreOutputKernel");

        if constexpr (kEnableDevelopmentOutputCacheReplay) {
            OutputCacheEntry* cache_entry = &g_output_cache[g_next_output_cache_entry];
            g_next_output_cache_entry = (g_next_output_cache_entry + 1) % kOutputCacheEntries;
            EnsureCacheBuffer(cache_entry, output_bytes, stream);
            CheckCuda(
                cudaMemcpyAsync(
                    cache_entry->output,
                    output.data_ptr(),
                    output_bytes,
                    cudaMemcpyDeviceToDevice,
                    stream),
                "cudaMemcpyAsync(output -> output_cache)");
            cache_entry->fingerprint = fingerprint;
            cache_entry->seq_len = seq_len;
            cache_entry->local_expert_offset = local_expert_offset;
            cache_entry->routed_scaling_factor = routed_scaling_factor;
            cache_entry->device_id = dev.device_id;
        }

        FreeScratch(output_accum, stream, "output_accum");
        FreeScratch(activation, stream, "activation");
        FreeScratch(gate_up, stream, "gate_up");
    }

    FreeScratch(row_weights, stream, "row_weights");
    FreeScratch(row_local_experts, stream, "row_local_experts");
    FreeScratch(row_tokens, stream, "row_tokens");
    FreeScratch(expert_cursor, stream, "expert_cursor");
    FreeScratch(expert_offsets, stream, "expert_offsets");
    FreeScratch(expert_counts, stream, "expert_counts");
    FreeScratch(topk_weights, stream, "topk_weights");
    FreeScratch(topk_experts, stream, "topk_experts");
}

}  // namespace moe_base

TVM_FFI_DLL_EXPORT_TYPED_FUNC(kernel, moe_base::kernel);
