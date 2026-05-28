#include <cuda_bf16.h>
#include <cuda_fp8.h>
#include <cuda_runtime.h>
#include <dlpack/dlpack.h>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/error.h>
#include <tvm/ffi/extra/c_env_api.h>
#include <tvm/ffi/function.h>

#include <algorithm>
#include <cfloat>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <vector>

#include <cutlass/cutlass.h>
#include <cutlass/gemm/device/gemm.h>
#include <cutlass/layout/matrix.h>

namespace hmdemo_mlsys26_contest {

using tvm::ffi::TensorView;

constexpr int32_t kHiddenSize = 7168;
constexpr int32_t kIntermediateSize = 2048;
constexpr int32_t kGemm1OutSize = 2 * kIntermediateSize;
constexpr int32_t kNumExpertsGlobal = 256;
constexpr int32_t kNumLocalExperts = 32;
constexpr int32_t kBlockSize = 128;
constexpr int32_t kHiddenBlocks = kHiddenSize / kBlockSize;
constexpr int32_t kIntermediateBlocks = kIntermediateSize / kBlockSize;
constexpr int32_t kGemm1OutBlocks = kGemm1OutSize / kBlockSize;
constexpr int32_t kTopK = 8;
constexpr int32_t kNumGroups = 8;
constexpr int32_t kTopKGroup = 4;
constexpr uint8_t kDTypeFloat8E4M3Fn = static_cast<uint8_t>(kDLFloat8_e4m3fn);

using BasicGemm = cutlass::gemm::device::Gemm<
    float,
    cutlass::layout::RowMajor,
    float,
    cutlass::layout::RowMajor,
    float,
    cutlass::layout::RowMajor,
    float>;

void check_cuda(cudaError_t status, const char* context) {
  if (status != cudaSuccess) {
    TVM_FFI_THROW(RuntimeError) << context << ": " << cudaGetErrorString(status);
  }
}

void check_cutlass(cutlass::Status status, const char* context) {
  if (status != cutlass::Status::kSuccess) {
    TVM_FFI_THROW(RuntimeError) << context << ": " << cutlassGetStatusString(status);
  }
}

void check_launch(const char* context) {
  check_cuda(cudaGetLastError(), context);
}

size_t checked_mul(size_t a, size_t b, const char* context) {
  if (a != 0 && b > std::numeric_limits<size_t>::max() / a) {
    TVM_FFI_THROW(RuntimeError) << "size overflow while allocating " << context;
  }
  return a * b;
}

class DeviceBuffer {
 public:
  DeviceBuffer() = default;

  DeviceBuffer(size_t bytes, cudaStream_t stream) : bytes_(bytes), stream_(stream) {
    if (bytes_ == 0) {
      return;
    }
    check_cuda(cudaMallocAsync(&ptr_, bytes_, stream_), "cudaMallocAsync");
  }

  ~DeviceBuffer() {
    if (ptr_ != nullptr) {
      cudaFreeAsync(ptr_, stream_);
    }
  }

  DeviceBuffer(const DeviceBuffer&) = delete;
  DeviceBuffer& operator=(const DeviceBuffer&) = delete;

  DeviceBuffer(DeviceBuffer&& other) noexcept
      : ptr_(other.ptr_), bytes_(other.bytes_), stream_(other.stream_) {
    other.ptr_ = nullptr;
    other.bytes_ = 0;
    other.stream_ = nullptr;
  }

  DeviceBuffer& operator=(DeviceBuffer&& other) noexcept {
    if (this != &other) {
      if (ptr_ != nullptr) {
        cudaFreeAsync(ptr_, stream_);
      }
      ptr_ = other.ptr_;
      bytes_ = other.bytes_;
      stream_ = other.stream_;
      other.ptr_ = nullptr;
      other.bytes_ = 0;
      other.stream_ = nullptr;
    }
    return *this;
  }

  template <typename T>
  T* data() {
    return static_cast<T*>(ptr_);
  }

  void* raw() {
    return ptr_;
  }

 private:
  void* ptr_ = nullptr;
  size_t bytes_ = 0;
  cudaStream_t stream_ = nullptr;
};

class CudaDeviceGuard {
 public:
  explicit CudaDeviceGuard(int device_id) : target_device_(device_id) {
    check_cuda(cudaGetDevice(&previous_device_), "cudaGetDevice");
    if (previous_device_ != target_device_) {
      check_cuda(cudaSetDevice(target_device_), "cudaSetDevice");
      changed_ = true;
    }
  }

  ~CudaDeviceGuard() {
    if (changed_) {
      cudaSetDevice(previous_device_);
    }
  }

  CudaDeviceGuard(const CudaDeviceGuard&) = delete;
  CudaDeviceGuard& operator=(const CudaDeviceGuard&) = delete;

 private:
  int target_device_ = 0;
  int previous_device_ = 0;
  bool changed_ = false;
};

void check_dtype(
    const TensorView& tensor,
    uint8_t code,
    uint8_t bits,
    const char* name,
    const char* expected) {
  const DLDataType dtype = tensor.dtype();
  if (dtype.code != code || dtype.bits != bits || dtype.lanes != 1) {
    TVM_FFI_THROW(TypeError)
        << name << " must have dtype " << expected << ", got code="
        << static_cast<int>(dtype.code) << ", bits=" << static_cast<int>(dtype.bits)
        << ", lanes=" << dtype.lanes;
  }
}

void check_rank(const TensorView& tensor, int32_t rank, const char* name) {
  if (tensor.ndim() != rank) {
    TVM_FFI_THROW(ValueError) << name << " must have rank " << rank;
  }
}

void check_cuda_tensor(const TensorView& tensor, const char* name) {
  const DLDevice device = tensor.device();
  if (device.device_type != kDLCUDA) {
    TVM_FFI_THROW(ValueError) << name << " must be a CUDA tensor";
  }
  if (!tensor.IsContiguous()) {
    TVM_FFI_THROW(ValueError) << name << " must be contiguous";
  }
  if (tensor.byte_offset() != 0) {
    TVM_FFI_THROW(ValueError) << name << " must have zero byte_offset";
  }
}

void check_same_device(const TensorView& reference, const TensorView& tensor, const char* name) {
  const DLDevice ref_device = reference.device();
  const DLDevice device = tensor.device();
  if (device.device_type != ref_device.device_type || device.device_id != ref_device.device_id) {
    TVM_FFI_THROW(ValueError) << name << " must be on the same CUDA device as routing_logits";
  }
}

void prepare_tensor(const TensorView& reference, const TensorView& tensor, const char* name) {
  check_cuda_tensor(tensor, name);
  check_same_device(reference, tensor, name);
}

void check_shape1(const TensorView& tensor, int64_t dim0, const char* name) {
  check_rank(tensor, 1, name);
  if (tensor.size(0) != dim0) {
    TVM_FFI_THROW(ValueError) << name << " has incorrect shape";
  }
}

void check_shape2(const TensorView& tensor, int64_t dim0, int64_t dim1, const char* name) {
  check_rank(tensor, 2, name);
  if (tensor.size(0) != dim0 || tensor.size(1) != dim1) {
    TVM_FFI_THROW(ValueError) << name << " has incorrect shape";
  }
}

void check_shape3(
    const TensorView& tensor,
    int64_t dim0,
    int64_t dim1,
    int64_t dim2,
    const char* name) {
  check_rank(tensor, 3, name);
  if (tensor.size(0) != dim0 || tensor.size(1) != dim1 || tensor.size(2) != dim2) {
    TVM_FFI_THROW(ValueError) << name << " has incorrect shape";
  }
}

void validate_inputs(
    const TensorView& routing_logits,
    const TensorView& routing_bias,
    const TensorView& hidden_states,
    const TensorView& hidden_states_scale,
    const TensorView& gemm1_weights,
    const TensorView& gemm1_weights_scale,
    const TensorView& gemm2_weights,
    const TensorView& gemm2_weights_scale,
    int64_t local_expert_offset,
    double routed_scaling_factor,
    const TensorView& output) {
  check_cuda_tensor(routing_logits, "routing_logits");
  check_dtype(routing_logits, kDLFloat, 32, "routing_logits", "float32");
  check_rank(routing_logits, 2, "routing_logits");
  const int64_t seq_len = routing_logits.size(0);
  if (routing_logits.size(1) != kNumExpertsGlobal) {
    TVM_FFI_THROW(ValueError) << "routing_logits.shape[1] must be 256";
  }

  prepare_tensor(routing_logits, routing_bias, "routing_bias");
  prepare_tensor(routing_logits, hidden_states, "hidden_states");
  prepare_tensor(routing_logits, hidden_states_scale, "hidden_states_scale");
  prepare_tensor(routing_logits, gemm1_weights, "gemm1_weights");
  prepare_tensor(routing_logits, gemm1_weights_scale, "gemm1_weights_scale");
  prepare_tensor(routing_logits, gemm2_weights, "gemm2_weights");
  prepare_tensor(routing_logits, gemm2_weights_scale, "gemm2_weights_scale");
  prepare_tensor(routing_logits, output, "output");

  check_dtype(routing_bias, kDLBfloat, 16, "routing_bias", "bfloat16");
  check_dtype(hidden_states, kDTypeFloat8E4M3Fn, 8, "hidden_states", "float8_e4m3fn");
  check_dtype(hidden_states_scale, kDLFloat, 32, "hidden_states_scale", "float32");
  check_dtype(gemm1_weights, kDTypeFloat8E4M3Fn, 8, "gemm1_weights", "float8_e4m3fn");
  check_dtype(gemm1_weights_scale, kDLFloat, 32, "gemm1_weights_scale", "float32");
  check_dtype(gemm2_weights, kDTypeFloat8E4M3Fn, 8, "gemm2_weights", "float8_e4m3fn");
  check_dtype(gemm2_weights_scale, kDLFloat, 32, "gemm2_weights_scale", "float32");
  check_dtype(output, kDLBfloat, 16, "output", "bfloat16");

  check_shape1(routing_bias, kNumExpertsGlobal, "routing_bias");
  check_shape2(hidden_states, seq_len, kHiddenSize, "hidden_states");
  check_shape2(hidden_states_scale, kHiddenBlocks, seq_len, "hidden_states_scale");
  check_shape3(gemm1_weights, kNumLocalExperts, kGemm1OutSize, kHiddenSize, "gemm1_weights");
  check_shape3(
      gemm1_weights_scale,
      kNumLocalExperts,
      kGemm1OutBlocks,
      kHiddenBlocks,
      "gemm1_weights_scale");
  check_shape3(gemm2_weights, kNumLocalExperts, kHiddenSize, kIntermediateSize, "gemm2_weights");
  check_shape3(
      gemm2_weights_scale,
      kNumLocalExperts,
      kHiddenBlocks,
      kIntermediateBlocks,
      "gemm2_weights_scale");
  check_shape2(output, seq_len, kHiddenSize, "output");

  if (local_expert_offset < 0 || local_expert_offset + kNumLocalExperts > kNumExpertsGlobal) {
    TVM_FFI_THROW(ValueError)
        << "local_expert_offset must select a valid 32-expert window within 256 experts";
  }
  if (!std::isfinite(routed_scaling_factor)) {
    TVM_FFI_THROW(ValueError) << "routed_scaling_factor must be finite";
  }
  if (seq_len > std::numeric_limits<int32_t>::max() / kTopK ||
      seq_len > std::numeric_limits<int32_t>::max() / kHiddenSize) {
    TVM_FFI_THROW(ValueError) << "seq_len is too large for this baseline";
  }
}

__device__ __forceinline__ float fp8_e4m3_to_float(uint8_t byte) {
  __nv_fp8_e4m3 value;
  memcpy(&value, &byte, 1);
  return static_cast<float>(value);
}

__global__ void route_topk_kernel(
    const float* __restrict__ routing_logits,
    const __nv_bfloat16* __restrict__ routing_bias,
    int32_t* __restrict__ topk_idx,
    float* __restrict__ topk_weight,
    float routed_scaling_factor,
    int32_t seq_len) {
  const int32_t token = static_cast<int32_t>(blockIdx.x);
  const int32_t expert = static_cast<int32_t>(threadIdx.x);
  if (token >= seq_len || expert >= kNumExpertsGlobal) {
    return;
  }

  __shared__ float biased_scores[kNumExpertsGlobal];
  __shared__ float scores[kNumExpertsGlobal];

  const float logit = routing_logits[token * kNumExpertsGlobal + expert];
  const float score = 1.0f / (1.0f + expf(-logit));
  scores[expert] = score;
  biased_scores[expert] = score + __bfloat162float(routing_bias[expert]);
  __syncthreads();

  if (expert != 0) {
    return;
  }

  float group_scores[kNumGroups];
  for (int32_t group = 0; group < kNumGroups; ++group) {
    float first = -FLT_MAX;
    float second = -FLT_MAX;
    const int32_t base = group * (kNumExpertsGlobal / kNumGroups);
    for (int32_t offset = 0; offset < kNumExpertsGlobal / kNumGroups; ++offset) {
      const float value = biased_scores[base + offset];
      if (value > first) {
        second = first;
        first = value;
      } else if (value > second) {
        second = value;
      }
    }
    group_scores[group] = first + second;
  }

  bool selected_groups[kNumGroups] = {};
  for (int32_t slot = 0; slot < kTopKGroup; ++slot) {
    float best = -FLT_MAX;
    int32_t best_group = -1;
    for (int32_t group = 0; group < kNumGroups; ++group) {
      if (!selected_groups[group] && group_scores[group] > best) {
        best = group_scores[group];
        best_group = group;
      }
    }
    if (best_group >= 0) {
      selected_groups[best_group] = true;
    }
  }

  int32_t selected_experts[kTopK];
  float selected_scores[kTopK];
  for (int32_t slot = 0; slot < kTopK; ++slot) {
    float best = -FLT_MAX;
    int32_t best_expert = -1;
    for (int32_t group = 0; group < kNumGroups; ++group) {
      if (!selected_groups[group]) {
        continue;
      }
      const int32_t base = group * (kNumExpertsGlobal / kNumGroups);
      for (int32_t offset = 0; offset < kNumExpertsGlobal / kNumGroups; ++offset) {
        const int32_t candidate = base + offset;
        const float value = biased_scores[candidate];
        if (value > best) {
          best = value;
          best_expert = candidate;
        }
      }
    }
    selected_experts[slot] = best_expert;
    selected_scores[slot] = best_expert >= 0 ? scores[best_expert] : 0.0f;
    if (best_expert >= 0) {
      biased_scores[best_expert] = -FLT_MAX;
    }
  }

  float score_sum = 0.0f;
  for (int32_t slot = 0; slot < kTopK; ++slot) {
    score_sum += selected_scores[slot];
  }
  score_sum = fmaxf(score_sum, 1.0e-20f);
  for (int32_t slot = 0; slot < kTopK; ++slot) {
    const int32_t out = token * kTopK + slot;
    topk_idx[out] = selected_experts[slot];
    topk_weight[out] = selected_scores[slot] / score_sum * routed_scaling_factor;
  }
}

__global__ void count_local_slots_kernel(
    const int32_t* __restrict__ topk_idx,
    int32_t* __restrict__ counts_by_expert,
    int32_t local_expert_offset,
    int32_t total_slots) {
  const int32_t slot = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (slot >= total_slots) {
    return;
  }
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (local_expert >= 0 && local_expert < kNumLocalExperts) {
    atomicAdd(&counts_by_expert[local_expert], 1);
  }
}

__global__ void build_offsets_kernel(
    const int32_t* __restrict__ counts_by_expert,
    int32_t* __restrict__ starts_by_expert,
    int32_t* __restrict__ write_offsets_by_expert,
    int32_t* __restrict__ total_local_slots) {
  int32_t total = 0;
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    starts_by_expert[expert] = total;
    write_offsets_by_expert[expert] = total;
    total += counts_by_expert[expert];
  }
  total_local_slots[0] = total;
}

__global__ void scatter_local_slots_kernel(
    const int32_t* __restrict__ topk_idx,
    const float* __restrict__ topk_weight,
    int32_t* __restrict__ write_offsets_by_expert,
    int32_t* __restrict__ compact_slot_ids,
    float* __restrict__ compact_weights,
    int32_t local_expert_offset,
    int32_t total_slots) {
  const int32_t slot = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (slot >= total_slots) {
    return;
  }
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (local_expert < 0 || local_expert >= kNumLocalExperts) {
    return;
  }
  const int32_t row = atomicAdd(&write_offsets_by_expert[local_expert], 1);
  compact_slot_ids[row] = slot;
  compact_weights[row] = topk_weight[slot];
}

__global__ void dequant_compact_activations_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const int32_t* __restrict__ compact_slot_ids,
    float* __restrict__ activations,
    int32_t start,
    int32_t count,
    int32_t seq_len) {
  const int64_t linear = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(count) * kHiddenSize;
  if (linear >= total) {
    return;
  }
  const int32_t row = static_cast<int32_t>(linear / kHiddenSize);
  const int32_t hidden = static_cast<int32_t>(linear - static_cast<int64_t>(row) * kHiddenSize);
  const int32_t slot = compact_slot_ids[start + row];
  const int32_t token = slot / kTopK;
  const float scale = hidden_states_scale[(hidden / kBlockSize) * seq_len + token];
  activations[linear] =
      fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) * scale;
}

__global__ void dequant_gemm1_weights_kernel(
    const uint8_t* __restrict__ gemm1_weights,
    const float* __restrict__ gemm1_weights_scale,
    float* __restrict__ gemm1_weight_t,
    int32_t local_expert) {
  const int64_t linear = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(kHiddenSize) * kGemm1OutSize;
  if (linear >= total) {
    return;
  }
  const int32_t hidden = static_cast<int32_t>(linear / kGemm1OutSize);
  const int32_t out = static_cast<int32_t>(linear - static_cast<int64_t>(hidden) * kGemm1OutSize);
  const float scale =
      gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (out / kBlockSize)) * kHiddenBlocks +
                          (hidden / kBlockSize)];
  gemm1_weight_t[linear] =
      fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + out) *
                                       kHiddenSize + hidden]) *
      scale;
}

__global__ void swiglu_kernel(
    const float* __restrict__ gemm1_out,
    float* __restrict__ gated,
    int32_t count) {
  const int64_t linear = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(count) * kIntermediateSize;
  if (linear >= total) {
    return;
  }
  const int32_t row = static_cast<int32_t>(linear / kIntermediateSize);
  const int32_t i = static_cast<int32_t>(linear - static_cast<int64_t>(row) * kIntermediateSize);
  const int64_t base = static_cast<int64_t>(row) * kGemm1OutSize;
  const float up = gemm1_out[base + i];
  const float gate = gemm1_out[base + kIntermediateSize + i];
  const float silu_gate = gate / (1.0f + expf(-gate));
  gated[linear] = silu_gate * up;
}

__global__ void dequant_gemm2_weights_kernel(
    const uint8_t* __restrict__ gemm2_weights,
    const float* __restrict__ gemm2_weights_scale,
    float* __restrict__ gemm2_weight_t,
    int32_t local_expert) {
  const int64_t linear = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(kIntermediateSize) * kHiddenSize;
  if (linear >= total) {
    return;
  }
  const int32_t intermediate =
      static_cast<int32_t>(linear / kHiddenSize);
  const int32_t hidden =
      static_cast<int32_t>(linear - static_cast<int64_t>(intermediate) * kHiddenSize);
  const float scale =
      gemm2_weights_scale[(local_expert * kHiddenBlocks + (hidden / kBlockSize)) *
                              kIntermediateBlocks +
                          (intermediate / kBlockSize)];
  gemm2_weight_t[linear] =
      fp8_e4m3_to_float(gemm2_weights[(static_cast<int64_t>(local_expert) * kHiddenSize + hidden) *
                                       kIntermediateSize + intermediate]) *
      scale;
}

__global__ void accumulate_weighted_output_kernel(
    const float* __restrict__ expert_output,
    const int32_t* __restrict__ compact_slot_ids,
    const float* __restrict__ compact_weights,
    float* __restrict__ output_fp32,
    int32_t start,
    int32_t count) {
  const int64_t linear = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(count) * kHiddenSize;
  if (linear >= total) {
    return;
  }
  const int32_t row = static_cast<int32_t>(linear / kHiddenSize);
  const int32_t hidden = static_cast<int32_t>(linear - static_cast<int64_t>(row) * kHiddenSize);
  const int32_t slot = compact_slot_ids[start + row];
  const int32_t token = slot / kTopK;
  const float weight = compact_weights[start + row];
  atomicAdd(
      &output_fp32[static_cast<int64_t>(token) * kHiddenSize + hidden],
      weight * expert_output[linear]);
}

__global__ void cast_output_kernel(
    const float* __restrict__ input,
    __nv_bfloat16* __restrict__ output,
    int32_t count) {
  const int32_t idx = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (idx < count) {
    output[idx] = __float2bfloat16(input[idx]);
  }
}

void run_basic_gemm(
    int32_t m,
    int32_t n,
    int32_t k,
    const float* a,
    const float* b,
    float* c,
    cudaStream_t stream,
    const char* context) {
  if (m == 0 || n == 0 || k == 0) {
    return;
  }
  BasicGemm gemm;
  BasicGemm::Arguments args(
      {m, n, k},
      {a, k},
      {b, n},
      {c, n},
      {c, n},
      {1.0f, 0.0f});
  check_cutlass(BasicGemm::can_implement(args), context);
  check_cutlass(gemm(args, nullptr, stream), context);
}

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
  validate_inputs(
      routing_logits,
      routing_bias,
      hidden_states,
      hidden_states_scale,
      gemm1_weights,
      gemm1_weights_scale,
      gemm2_weights,
      gemm2_weights_scale,
      local_expert_offset,
      routed_scaling_factor,
      output);

  const int32_t seq_len = static_cast<int32_t>(routing_logits.size(0));
  if (seq_len == 0) {
    return;
  }

  const DLDevice device = routing_logits.device();
  CudaDeviceGuard device_guard(device.device_id);
  cudaStream_t stream =
      static_cast<cudaStream_t>(TVMFFIEnvGetStream(device.device_type, device.device_id));

  const int32_t total_slots = seq_len * kTopK;
  const int32_t total_output = seq_len * kHiddenSize;
  constexpr int32_t kThreads = 256;

  DeviceBuffer topk_idx(checked_mul(total_slots, sizeof(int32_t), "topk_idx"), stream);
  DeviceBuffer topk_weight(checked_mul(total_slots, sizeof(float), "topk_weight"), stream);
  DeviceBuffer counts(checked_mul(kNumLocalExperts, sizeof(int32_t), "counts"), stream);
  DeviceBuffer starts(checked_mul(kNumLocalExperts, sizeof(int32_t), "starts"), stream);
  DeviceBuffer offsets(checked_mul(kNumLocalExperts, sizeof(int32_t), "offsets"), stream);
  DeviceBuffer total_local(sizeof(int32_t), stream);
  DeviceBuffer compact_slot_ids(
      checked_mul(total_slots, sizeof(int32_t), "compact_slot_ids"), stream);
  DeviceBuffer compact_weights(checked_mul(total_slots, sizeof(float), "compact_weights"), stream);
  DeviceBuffer output_fp32(checked_mul(total_output, sizeof(float), "output_fp32"), stream);

  check_cuda(cudaMemsetAsync(counts.raw(), 0, kNumLocalExperts * sizeof(int32_t), stream), "zero counts");
  check_cuda(cudaMemsetAsync(output_fp32.raw(), 0, total_output * sizeof(float), stream), "zero output");

  route_topk_kernel<<<seq_len, kNumExpertsGlobal, 0, stream>>>(
      static_cast<const float*>(routing_logits.data_ptr()),
      static_cast<const __nv_bfloat16*>(routing_bias.data_ptr()),
      topk_idx.data<int32_t>(),
      topk_weight.data<float>(),
      static_cast<float>(routed_scaling_factor),
      seq_len);
  check_launch("route_topk_kernel");

  const int32_t slot_blocks = (total_slots + kThreads - 1) / kThreads;
  count_local_slots_kernel<<<slot_blocks, kThreads, 0, stream>>>(
      topk_idx.data<int32_t>(),
      counts.data<int32_t>(),
      static_cast<int32_t>(local_expert_offset),
      total_slots);
  check_launch("count_local_slots_kernel");

  build_offsets_kernel<<<1, 1, 0, stream>>>(
      counts.data<int32_t>(),
      starts.data<int32_t>(),
      offsets.data<int32_t>(),
      total_local.data<int32_t>());
  check_launch("build_offsets_kernel");

  scatter_local_slots_kernel<<<slot_blocks, kThreads, 0, stream>>>(
      topk_idx.data<int32_t>(),
      topk_weight.data<float>(),
      offsets.data<int32_t>(),
      compact_slot_ids.data<int32_t>(),
      compact_weights.data<float>(),
      static_cast<int32_t>(local_expert_offset),
      total_slots);
  check_launch("scatter_local_slots_kernel");

  std::vector<int32_t> counts_host(kNumLocalExperts);
  std::vector<int32_t> starts_host(kNumLocalExperts);
  int32_t total_local_host = 0;
  check_cuda(
      cudaMemcpyAsync(
          counts_host.data(),
          counts.data<int32_t>(),
          kNumLocalExperts * sizeof(int32_t),
          cudaMemcpyDeviceToHost,
          stream),
      "copy counts");
  check_cuda(
      cudaMemcpyAsync(
          starts_host.data(),
          starts.data<int32_t>(),
          kNumLocalExperts * sizeof(int32_t),
          cudaMemcpyDeviceToHost,
          stream),
      "copy starts");
  check_cuda(
      cudaMemcpyAsync(
          &total_local_host,
          total_local.data<int32_t>(),
          sizeof(int32_t),
          cudaMemcpyDeviceToHost,
          stream),
      "copy total local slots");
  check_cuda(cudaStreamSynchronize(stream), "sync compact metadata");

  const int32_t max_count =
      *std::max_element(counts_host.begin(), counts_host.end());
  if (total_local_host > 0 && max_count > 0) {
    DeviceBuffer activations(
        checked_mul(
            checked_mul(max_count, kHiddenSize, "activation elements"),
            sizeof(float),
            "activations"),
        stream);
    DeviceBuffer gemm1_weight_t(
        checked_mul(
            checked_mul(kHiddenSize, kGemm1OutSize, "gemm1 weight elements"),
            sizeof(float),
            "gemm1 weights"),
        stream);
    DeviceBuffer gemm1_out(
        checked_mul(
            checked_mul(max_count, kGemm1OutSize, "gemm1 output elements"),
            sizeof(float),
            "gemm1 output"),
        stream);
    DeviceBuffer gated(
        checked_mul(
            checked_mul(max_count, kIntermediateSize, "gated elements"),
            sizeof(float),
            "gated"),
        stream);
    DeviceBuffer gemm2_weight_t(
        checked_mul(
            checked_mul(kIntermediateSize, kHiddenSize, "gemm2 weight elements"),
            sizeof(float),
            "gemm2 weights"),
        stream);
    DeviceBuffer expert_output(
        checked_mul(
            checked_mul(max_count, kHiddenSize, "expert output elements"),
            sizeof(float),
            "expert output"),
        stream);

    for (int32_t local_expert = 0; local_expert < kNumLocalExperts; ++local_expert) {
      const int32_t count = counts_host[local_expert];
      if (count == 0) {
        continue;
      }
      const int32_t start = starts_host[local_expert];

      const int64_t activation_elems = static_cast<int64_t>(count) * kHiddenSize;
      const int64_t gemm1_weight_elems = static_cast<int64_t>(kHiddenSize) * kGemm1OutSize;
      dequant_compact_activations_kernel<<<
          static_cast<int32_t>((activation_elems + kThreads - 1) / kThreads),
          kThreads,
          0,
          stream>>>(
          static_cast<const uint8_t*>(hidden_states.data_ptr()),
          static_cast<const float*>(hidden_states_scale.data_ptr()),
          compact_slot_ids.data<int32_t>(),
          activations.data<float>(),
          start,
          count,
          seq_len);
      check_launch("dequant_compact_activations_kernel");

      dequant_gemm1_weights_kernel<<<
          static_cast<int32_t>((gemm1_weight_elems + kThreads - 1) / kThreads),
          kThreads,
          0,
          stream>>>(
          static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
          static_cast<const float*>(gemm1_weights_scale.data_ptr()),
          gemm1_weight_t.data<float>(),
          local_expert);
      check_launch("dequant_gemm1_weights_kernel");

      run_basic_gemm(
          count,
          kGemm1OutSize,
          kHiddenSize,
          activations.data<float>(),
          gemm1_weight_t.data<float>(),
          gemm1_out.data<float>(),
          stream,
          "cutlass gemm1");

      const int64_t gated_elems = static_cast<int64_t>(count) * kIntermediateSize;
      swiglu_kernel<<<
          static_cast<int32_t>((gated_elems + kThreads - 1) / kThreads),
          kThreads,
          0,
          stream>>>(gemm1_out.data<float>(), gated.data<float>(), count);
      check_launch("swiglu_kernel");

      const int64_t gemm2_weight_elems = static_cast<int64_t>(kIntermediateSize) * kHiddenSize;
      dequant_gemm2_weights_kernel<<<
          static_cast<int32_t>((gemm2_weight_elems + kThreads - 1) / kThreads),
          kThreads,
          0,
          stream>>>(
          static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
          static_cast<const float*>(gemm2_weights_scale.data_ptr()),
          gemm2_weight_t.data<float>(),
          local_expert);
      check_launch("dequant_gemm2_weights_kernel");

      run_basic_gemm(
          count,
          kHiddenSize,
          kIntermediateSize,
          gated.data<float>(),
          gemm2_weight_t.data<float>(),
          expert_output.data<float>(),
          stream,
          "cutlass gemm2");

      const int64_t expert_output_elems = static_cast<int64_t>(count) * kHiddenSize;
      accumulate_weighted_output_kernel<<<
          static_cast<int32_t>((expert_output_elems + kThreads - 1) / kThreads),
          kThreads,
          0,
          stream>>>(
          expert_output.data<float>(),
          compact_slot_ids.data<int32_t>(),
          compact_weights.data<float>(),
          output_fp32.data<float>(),
          start,
          count);
      check_launch("accumulate_weighted_output_kernel");
    }
  }

  cast_output_kernel<<<(total_output + kThreads - 1) / kThreads, kThreads, 0, stream>>>(
      output_fp32.data<float>(),
      static_cast<__nv_bfloat16*>(output.data_ptr()),
      total_output);
  check_launch("cast_output_kernel");
}

}  // namespace hmdemo_mlsys26_contest

TVM_FFI_DLL_EXPORT_TYPED_FUNC(kernel, hmdemo_mlsys26_contest::kernel);
