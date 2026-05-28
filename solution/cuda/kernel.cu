#include <cuda_bf16.h>
#include <cuda_fp8.h>
#include <cuda_runtime.h>
#include <dlpack/dlpack.h>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/error.h>
#include <tvm/ffi/extra/c_env_api.h>
#include <tvm/ffi/function.h>

#include <cfloat>
#include <cmath>
#include <atomic>
#include <cstdint>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <limits>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <utility>
#include <vector>

#ifndef LCR_ENABLE_CUTLASS92_TVM_FFI
#define LCR_ENABLE_CUTLASS92_TVM_FFI 1
#endif

#include "cute/tensor.hpp"
#include "cutlass/cutlass.h"
#include "cutlass/epilogue/collective/collective_builder.hpp"
#include "cutlass/gemm/collective/collective_builder.hpp"
#include "cutlass/gemm/device/gemm_universal_adapter.h"
#include "cutlass/gemm/group_array_problem_shape.hpp"
#include "cutlass/gemm/kernel/gemm_universal.hpp"
#include "cutlass/util/packed_stride.hpp"

namespace moe_tvm_ffi {

constexpr int32_t kHiddenSize = 7168;
constexpr int32_t kIntermediateSize = 2048;
constexpr int32_t kNumExpertsGlobal = 256;
constexpr int32_t kNumLocalExperts = 32;
constexpr int32_t kBlockSize = 128;
constexpr int32_t kTopK = 8;
constexpr int32_t kNumGroups = 8;
constexpr int32_t kTopKGroup = 4;
constexpr int32_t kHiddenBlocks = kHiddenSize / kBlockSize;
constexpr int32_t kIntermediateBlocks = kIntermediateSize / kBlockSize;
constexpr int32_t kGemm1OutSize = 2 * kIntermediateSize;
constexpr int32_t kGemm1OutBlocks = kGemm1OutSize / kBlockSize;
constexpr int32_t kCompactHiddenBlocksPerTile = 4;
constexpr int32_t kCompactHiddenThreads = 256;
constexpr int32_t kCompactHiddenElemsPerThread =
    (kBlockSize * kCompactHiddenBlocksPerTile) / kCompactHiddenThreads;
constexpr int32_t kCompactHiddenTileSize = kBlockSize * kCompactHiddenBlocksPerTile;
constexpr int32_t kCompactHiddenTiles = kHiddenBlocks / kCompactHiddenBlocksPerTile;
constexpr int32_t kShortCutlassGemm1PackThreads = 128;
constexpr int32_t kShortCutlassGemm1PackElemsPerThread =
    kCompactHiddenTileSize / kShortCutlassGemm1PackThreads;
constexpr int32_t kShortCutlassGemm2PackThreads = 64;
constexpr int32_t kShortCutlassGemm2PackElemsPerThread =
    kBlockSize / kShortCutlassGemm2PackThreads;
constexpr int32_t kCompactScalarSmallSeqLenGate = 32;
constexpr int32_t kCompactScalarSeqLenGate = 128;
constexpr int32_t kCutlass92MediumSeqLenGate = 48;
constexpr int32_t kInvalidToken = -1;
constexpr float kFp8E4m3MaxFinite = 448.0f;
constexpr uint8_t kDTypeFloat8E4M3Fn = static_cast<uint8_t>(kDLFloat8_e4m3fn);
constexpr const char* kDisableCompactScalarEnv = "LCR_DISABLE_COMPACT_SCALAR_PATH";
constexpr const char* kEnableCompactScalarEnv = "LCR_ENABLE_COMPACT_SCALAR_PATH";
constexpr const char* kEnableCompactScalarSmallSeqEnv = "LCR_ENABLE_COMPACT_SCALAR_SMALL_SEQ";
constexpr const char* kDisableCutlass92Env = "LCR_DISABLE_CUTLASS92";
constexpr const char* kDisableCutlass92Gemm2Env = "LCR_DISABLE_CUTLASS92_GEMM2";
constexpr const char* kEnableCutlass92HostCountSyncEnv = "LCR_ENABLE_CUTLASS92_HOST_COUNT_SYNC";
constexpr const char* kForceCutlass921SmEnv = "LCR_FORCE_CUTLASS92_1SM";
constexpr const char* kForceCutlass922SmEnv = "LCR_FORCE_CUTLASS92_2SM";
constexpr const char* kEnableCutlass92PdlEnv = "LCR_ENABLE_CUTLASS92_PDL";
constexpr const char* kEnableCutlass92StatelessDiagnosticEnv = "LCR_ENABLE_CUTLASS92_STATELESS_DIAGNOSTIC";
constexpr const char* kEnableCutlass92PathTraceEnv = "LCR_ENABLE_CUTLASS92_PATH_TRACE";
constexpr const char* kEnableInvocationIntegrityDiagnosticEnv = "LCR_ENABLE_INVOCATION_INTEGRITY_DIAGNOSTIC";
constexpr const char* kEnablePrivateStreamExecutionDiagnosticEnv = "LCR_ENABLE_PRIVATE_STREAM_EXECUTION_DIAGNOSTIC";
constexpr const char* kEnableDeviceWideFenceDiagnosticEnv = "LCR_ENABLE_DEVICE_WIDE_FENCE_DIAGNOSTIC";
constexpr const char* kEnableReusableTempDiagnosticEnv = "LCR_ENABLE_REUSABLE_TEMP_DIAGNOSTIC";
constexpr const char* kEnableFullTempStateInitDiagnosticEnv = "LCR_ENABLE_FULL_TEMP_STATE_INIT_DIAGNOSTIC";
constexpr const char* kTempStateInitFamiliesEnv = "LCR_TEMP_STATE_INIT_FAMILIES";
constexpr const char* kEnableCutlass92StageValidationDiagnosticEnv =
    "LCR_ENABLE_CUTLASS92_STAGE_VALIDATION_DIAGNOSTIC";
constexpr const char* kEnableCutlass92PerturbationBisectionDiagnosticEnv =
    "LCR_ENABLE_CUTLASS92_PERTURBATION_BISECTION_DIAGNOSTIC";
constexpr const char* kCutlass92PerturbationSubsetEnv = "LCR_CUTLASS92_PERTURBATION_SUBSET";
constexpr const char* kEnablePostGemm2MaterializationDiagnosticEnv =
    "LCR_ENABLE_POST_GEMM2_MATERIALIZATION_DIAGNOSTIC";
constexpr const char* kEnableGemm2RefComponentBisectionDiagnosticEnv =
    "LCR_ENABLE_GEMM2_REF_COMPONENT_BISECTION_DIAGNOSTIC";
constexpr const char* kGemm2RefComponentSubsetEnv = "LCR_GEMM2_REF_COMPONENT_SUBSET";
constexpr const char* kEnablePrepareReferenceComponentBisectionDiagnosticEnv =
    "LCR_ENABLE_PREPARE_REFERENCE_COMPONENT_BISECTION_DIAGNOSTIC";
constexpr const char* kPrepareReferenceComponentSubsetEnv = "LCR_PREPARE_REFERENCE_COMPONENT_SUBSET";
constexpr const char* kEnableFp32FinalizationDiagnosticEnv = "LCR_ENABLE_FP32_FINALIZATION_DIAGNOSTIC";
constexpr const char* kDebugCompactMetadataEnv = "LCR_DEBUG_COMPACT_METADATA";
constexpr const char* kDebugCompareCutlass92Env = "LCR_DEBUG_COMPARE_CUTLASS92";
constexpr int32_t kCutlass922SmSeqLenGate = 512;
constexpr int32_t kDebugCompareCutlass92MaxSeqLen = 1024;
constexpr float kDebugCompareMinMatchedRatio = 0.85f;
constexpr uint8_t kIntegrityPoisonByte = 0xA5;
constexpr uint8_t kIntegrityGuardByte = 0xD3;
constexpr size_t kIntegrityGuardBytes = 256;

void check_cuda(cudaError_t status, const char* context) {
  if (status != cudaSuccess) {
    TVM_FFI_THROW(RuntimeError) << context << ": " << cudaGetErrorString(status);
  }
}

void check_launch(const char* context) {
  check_cuda(cudaGetLastError(), context);
}

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

class DeviceBuffer {
 public:
  DeviceBuffer() = default;

  DeviceBuffer(size_t bytes, cudaStream_t stream) : bytes_(bytes), stream_(stream) {
    if (bytes_ == 0) {
      return;
    }
    cudaError_t status = cudaMallocAsync(&ptr_, bytes_, stream_);
    if (status == cudaSuccess) {
      async_allocated_ = true;
      return;
    }
    if (status == cudaErrorNotSupported || status == cudaErrorInvalidValue) {
      check_cuda(cudaMalloc(&ptr_, bytes_), "cudaMalloc fallback");
      async_allocated_ = false;
      return;
    }
    check_cuda(status, "cudaMallocAsync");
  }

  ~DeviceBuffer() {
    free();
  }

  DeviceBuffer(DeviceBuffer&& other) noexcept
      : ptr_(other.ptr_),
        bytes_(other.bytes_),
        stream_(other.stream_),
        async_allocated_(other.async_allocated_) {
    other.ptr_ = nullptr;
    other.bytes_ = 0;
    other.stream_ = nullptr;
    other.async_allocated_ = false;
  }

  DeviceBuffer& operator=(DeviceBuffer&& other) noexcept {
    if (this != &other) {
      free();
      ptr_ = other.ptr_;
      bytes_ = other.bytes_;
      stream_ = other.stream_;
      async_allocated_ = other.async_allocated_;
      other.ptr_ = nullptr;
      other.bytes_ = 0;
      other.stream_ = nullptr;
      other.async_allocated_ = false;
    }
    return *this;
  }

  DeviceBuffer(const DeviceBuffer&) = delete;
  DeviceBuffer& operator=(const DeviceBuffer&) = delete;

  template <typename T>
  T* data() {
    return static_cast<T*>(ptr_);
  }

  void* raw() {
    return ptr_;
  }

  size_t bytes() const {
    return bytes_;
  }

 private:
  void free() {
    if (ptr_ == nullptr) {
      return;
    }
    if (async_allocated_) {
      cudaFreeAsync(ptr_, stream_);
    } else {
      cudaFree(ptr_);
    }
    ptr_ = nullptr;
    bytes_ = 0;
    stream_ = nullptr;
    async_allocated_ = false;
  }

  void* ptr_ = nullptr;
  size_t bytes_ = 0;
  cudaStream_t stream_ = nullptr;
  bool async_allocated_ = false;
};

void poison_device_region(void* ptr, size_t bytes, cudaStream_t stream, const char* name) {
  if (ptr == nullptr || bytes == 0) {
    return;
  }
  check_cuda(cudaMemsetAsync(ptr, kIntegrityPoisonByte, bytes, stream), name);
}

void zero_device_region(void* ptr, size_t bytes, cudaStream_t stream, const char* name) {
  if (ptr == nullptr || bytes == 0) {
    return;
  }
  check_cuda(cudaMemsetAsync(ptr, 0, bytes, stream), name);
}

struct IntegrityGuardRegion {
  const uint8_t* ptr = nullptr;
  size_t bytes = 0;
  const char* name = nullptr;
};

std::atomic<uint64_t> g_kernel_invocation_counter{0};
std::mutex g_private_execution_streams_mutex;
std::unordered_map<int32_t, cudaStream_t> g_private_execution_streams;

struct ReusableTempCacheKey {
  int32_t device_index = 0;
  uintptr_t stream = 0;

  bool operator==(const ReusableTempCacheKey& other) const {
    return device_index == other.device_index && stream == other.stream;
  }
};

struct ReusableTempCacheKeyHash {
  std::size_t operator()(const ReusableTempCacheKey& key) const {
    std::size_t seed = std::hash<int32_t>{}(key.device_index);
    seed ^= std::hash<uintptr_t>{}(key.stream) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    return seed;
  }
};

struct ReusableBufferAcquireResult {
  void* ptr = nullptr;
  size_t bytes = 0;
  bool reused = false;
  bool grew = false;
};

class ReusableDeviceBuffer {
 public:
  ReusableBufferAcquireResult ensure(size_t bytes, cudaStream_t stream) {
    ReusableBufferAcquireResult result;
    if (bytes == 0) {
      return result;
    }
    if (buffer_.raw() != nullptr && buffer_.bytes() >= bytes) {
      result.ptr = buffer_.raw();
      result.bytes = buffer_.bytes();
      result.reused = true;
      return result;
    }
    buffer_ = DeviceBuffer(bytes, stream);
    result.ptr = buffer_.raw();
    result.bytes = buffer_.bytes();
    result.grew = true;
    return result;
  }

 private:
  DeviceBuffer buffer_;
};

struct ReusableTempBuffers {
  ReusableDeviceBuffer workspace;
  ReusableDeviceBuffer row_owner_local_expert;
  ReusableDeviceBuffer row_owner_expert_row;
};

std::mutex g_reusable_temp_buffers_mutex;
std::unordered_map<ReusableTempCacheKey, std::shared_ptr<ReusableTempBuffers>, ReusableTempCacheKeyHash>
    g_reusable_temp_buffers;

class ScopedCudaEvent {
 public:
  ScopedCudaEvent() {
    check_cuda(cudaEventCreateWithFlags(&event_, cudaEventDisableTiming), "cudaEventCreateWithFlags");
  }

  ~ScopedCudaEvent() {
    if (event_ != nullptr) {
      cudaEventDestroy(event_);
    }
  }

  ScopedCudaEvent(const ScopedCudaEvent&) = delete;
  ScopedCudaEvent& operator=(const ScopedCudaEvent&) = delete;

  cudaEvent_t get() const {
    return event_;
  }

 private:
  cudaEvent_t event_ = nullptr;
};

cudaStream_t cached_private_execution_stream(int32_t device_index) {
  std::lock_guard<std::mutex> lock(g_private_execution_streams_mutex);
  const auto it = g_private_execution_streams.find(device_index);
  if (it != g_private_execution_streams.end()) {
    return it->second;
  }
  cudaStream_t stream = nullptr;
  check_cuda(cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking), "cudaStreamCreateWithFlags private stream");
  g_private_execution_streams.emplace(device_index, stream);
  return stream;
}

std::shared_ptr<ReusableTempBuffers> cached_reusable_temp_buffers(
    int32_t device_index,
    cudaStream_t stream) {
  const ReusableTempCacheKey key{device_index, reinterpret_cast<uintptr_t>(stream)};
  std::lock_guard<std::mutex> lock(g_reusable_temp_buffers_mutex);
  const auto it = g_reusable_temp_buffers.find(key);
  if (it != g_reusable_temp_buffers.end()) {
    return it->second;
  }
  auto buffers = std::make_shared<ReusableTempBuffers>();
  g_reusable_temp_buffers.emplace(key, buffers);
  return buffers;
}

struct ExecutionStreamTrace {
  uint64_t invocation_id = 0;
  int32_t device_index = 0;
  cudaStream_t caller_stream = nullptr;
  cudaStream_t execution_stream = nullptr;
  int32_t seq_len = 0;
  bool private_stream_active = false;
  bool device_fence_active = false;
  bool reusable_temp_active = false;
  bool full_temp_init_active = false;
  bool workspace_reused = false;
  bool workspace_grew = false;
  bool row_owner_reused = false;
  bool row_owner_grew = false;
  bool init_workspace_family = false;
  bool init_row_owner_family = false;
  bool init_cutlass_launch_family = false;
};

void maybe_log_execution_stream_trace(
    bool enabled,
    const char* phase,
    const ExecutionStreamTrace& trace,
    const char* path) {
  if (!enabled) {
    return;
  }
  std::fprintf(
      stderr,
      "[stream-trace] phase=%s invocation=%llu device=%d caller_stream=0x%llx execution_stream=0x%llx seq_len=%d private_stream=%d device_fence=%d reusable_temp=%d full_temp_init=%d workspace_reused=%d workspace_grew=%d row_owner_reused=%d row_owner_grew=%d init_workspace=%d init_row_owner=%d init_cutlass_launch=%d path=%s\n",
      phase,
      static_cast<unsigned long long>(trace.invocation_id),
      trace.device_index,
      static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(trace.caller_stream)),
      static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(trace.execution_stream)),
      trace.seq_len,
      trace.private_stream_active ? 1 : 0,
      trace.device_fence_active ? 1 : 0,
      trace.reusable_temp_active ? 1 : 0,
      trace.full_temp_init_active ? 1 : 0,
      trace.workspace_reused ? 1 : 0,
      trace.workspace_grew ? 1 : 0,
      trace.row_owner_reused ? 1 : 0,
      trace.row_owner_grew ? 1 : 0,
      trace.init_workspace_family ? 1 : 0,
      trace.init_row_owner_family ? 1 : 0,
      trace.init_cutlass_launch_family ? 1 : 0,
      path);
  std::fflush(stderr);
}

class InvocationIntegrityMonitor {
 public:
  InvocationIntegrityMonitor(
      bool enabled,
      uint64_t invocation_id,
      int32_t device_index,
      cudaStream_t caller_stream,
      cudaStream_t execution_stream,
      int32_t seq_len,
      bool use_compact_execution,
      bool use_short_seq_metadata_fastpath,
      bool cutlass_runtime_enabled,
      bool private_stream_active,
      bool device_fence_active)
      : enabled_(enabled),
        invocation_id_(invocation_id),
        device_index_(device_index),
        caller_stream_(caller_stream),
        execution_stream_(execution_stream),
        seq_len_(seq_len),
        use_compact_execution_(use_compact_execution),
        use_short_seq_metadata_fastpath_(use_short_seq_metadata_fastpath),
        cutlass_runtime_enabled_(cutlass_runtime_enabled),
        private_stream_active_(private_stream_active),
        device_fence_active_(device_fence_active) {}

  bool enabled() const {
    return enabled_;
  }

  uint64_t invocation_id() const {
    return invocation_id_;
  }

  void set_path(const char* path) {
    if (enabled_) {
      path_ = path;
    }
  }

  void log_start() const {
    if (!enabled_) {
      return;
    }
    std::fprintf(
        stderr,
        "[integrity] phase=start invocation=%llu device=%d caller_stream=0x%llx execution_stream=0x%llx seq_len=%d compact=%d short_meta=%d cutlass_runtime=%d private_stream=%d device_fence=%d path=%s\n",
        static_cast<unsigned long long>(invocation_id_),
        device_index_,
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(caller_stream_)),
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(execution_stream_)),
        seq_len_,
        use_compact_execution_ ? 1 : 0,
        use_short_seq_metadata_fastpath_ ? 1 : 0,
        cutlass_runtime_enabled_ ? 1 : 0,
        private_stream_active_ ? 1 : 0,
        device_fence_active_ ? 1 : 0,
        path_);
    std::fflush(stderr);
  }

  void log_end() const {
    if (!enabled_) {
      return;
    }
    std::fprintf(
        stderr,
        "[integrity] phase=end invocation=%llu device=%d caller_stream=0x%llx execution_stream=0x%llx seq_len=%d private_stream=%d device_fence=%d path=%s\n",
        static_cast<unsigned long long>(invocation_id_),
        device_index_,
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(caller_stream_)),
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(execution_stream_)),
        seq_len_,
        private_stream_active_ ? 1 : 0,
        device_fence_active_ ? 1 : 0,
        path_);
    std::fflush(stderr);
  }

  void poison_region(void* ptr, size_t bytes, const char* name) const {
    if (!enabled_) {
      return;
    }
    poison_device_region(ptr, bytes, execution_stream_, name);
  }

  void register_tail_guard(void* base, size_t used_bytes, size_t allocation_bytes, const char* name) {
    if (!enabled_ || base == nullptr || allocation_bytes <= used_bytes) {
      return;
    }
    const size_t guard_bytes = (allocation_bytes - used_bytes) < kIntegrityGuardBytes
        ? (allocation_bytes - used_bytes)
        : kIntegrityGuardBytes;
    if (guard_bytes == 0) {
      return;
    }
    uint8_t* guard_ptr = static_cast<uint8_t*>(base) + used_bytes;
    check_cuda(cudaMemsetAsync(guard_ptr, kIntegrityGuardByte, guard_bytes, execution_stream_), name);
    guards_.push_back({guard_ptr, guard_bytes, name});
  }

  void synchronize_and_validate() const {
    if (!enabled_) {
      return;
    }
    check_cuda(cudaStreamSynchronize(execution_stream_), "cudaStreamSynchronize invocation integrity");
    for (const IntegrityGuardRegion& guard : guards_) {
      validate_guard_region(guard);
    }
  }

 private:
  void validate_guard_region(const IntegrityGuardRegion& guard) const {
    std::vector<uint8_t> host(guard.bytes);
    check_cuda(
        cudaMemcpy(host.data(), guard.ptr, guard.bytes, cudaMemcpyDeviceToHost),
        "cudaMemcpy invocation integrity guard");
    for (size_t i = 0; i < host.size(); ++i) {
      if (host[i] != kIntegrityGuardByte) {
        std::fprintf(
            stderr,
            "[integrity] phase=corrupt invocation=%llu seq_len=%d path=%s guard=%s offset=%zu expected=0x%02x found=0x%02x\n",
            static_cast<unsigned long long>(invocation_id_),
            seq_len_,
            path_,
            guard.name,
            i,
            static_cast<unsigned>(kIntegrityGuardByte),
            static_cast<unsigned>(host[i]));
        std::fflush(stderr);
        TVM_FFI_THROW(RuntimeError)
            << "Invocation integrity guard corrupted for " << guard.name
            << " at offset " << i << " on invocation " << invocation_id_;
      }
    }
  }

  bool enabled_ = false;
  uint64_t invocation_id_ = 0;
  int32_t device_index_ = 0;
  cudaStream_t caller_stream_ = nullptr;
  cudaStream_t execution_stream_ = nullptr;
  int32_t seq_len_ = 0;
  bool use_compact_execution_ = false;
  bool use_short_seq_metadata_fastpath_ = false;
  bool cutlass_runtime_enabled_ = false;
  bool private_stream_active_ = false;
  bool device_fence_active_ = false;
  const char* path_ = "unassigned";
  std::vector<IntegrityGuardRegion> guards_;
};

size_t checked_bytes(int64_t elements, size_t element_size, const char* name) {
  if (elements < 0) {
    TVM_FFI_THROW(ValueError) << name << " element count must be non-negative";
  }
  const auto unsigned_elements = static_cast<uint64_t>(elements);
  if (element_size != 0 && unsigned_elements > std::numeric_limits<size_t>::max() / element_size) {
    TVM_FFI_THROW(OverflowError) << name << " allocation is too large";
  }
  return static_cast<size_t>(unsigned_elements) * element_size;
}

size_t align_up(size_t value, size_t alignment) {
  const size_t mask = alignment - 1;
  return (value + mask) & ~mask;
}

class CudaWorkspace {
 public:
  CudaWorkspace(size_t bytes, cudaStream_t stream, bool integrity_diagnostic)
      : owned_buffer_(bytes, stream),
        base_(static_cast<uint8_t*>(owned_buffer_.raw())),
        capacity_(owned_buffer_.bytes()),
        integrity_diagnostic_(integrity_diagnostic),
        stream_(stream) {
    if (integrity_diagnostic_ && capacity_ > 0) {
      poison_device_region(base_, capacity_, stream_, "cudaMemsetAsync workspace poison");
    }
  }

  CudaWorkspace(void* ptr, size_t bytes, cudaStream_t stream, bool integrity_diagnostic)
      : base_(static_cast<uint8_t*>(ptr)),
        capacity_(bytes),
        integrity_diagnostic_(integrity_diagnostic),
        stream_(stream) {
    if (integrity_diagnostic_ && bytes > 0) {
      poison_device_region(base_, bytes, stream_, "cudaMemsetAsync workspace poison");
    }
  }

  template <typename T>
  T* alloc(int64_t elements, const char* name) {
    const size_t bytes = checked_bytes(elements, sizeof(T), name);
    offset_ = align_up(offset_, kAlignment);
    if (bytes > capacity_ || offset_ > capacity_ - bytes) {
      TVM_FFI_THROW(OverflowError) << name << " exceeds optimized-path workspace";
    }
    uint8_t* base = base_ + offset_;
    offset_ += bytes;
    if (integrity_diagnostic_) {
      const size_t guard_bytes =
          (offset_ <= capacity_ && capacity_ - offset_ >= kIntegrityGuardBytes) ? kIntegrityGuardBytes : 0;
      if (guard_bytes > 0) {
        uint8_t* guard_ptr = base_ + offset_;
        check_cuda(cudaMemsetAsync(guard_ptr, kIntegrityGuardByte, guard_bytes, stream_), name);
        guards_.push_back({guard_ptr, guard_bytes, name});
        offset_ += guard_bytes;
      }
    }
    return reinterpret_cast<T*>(base);
  }

  void validate_guards() const {
    if (!integrity_diagnostic_) {
      return;
    }
    for (const IntegrityGuardRegion& guard : guards_) {
      std::vector<uint8_t> host(guard.bytes);
      check_cuda(
          cudaMemcpy(host.data(), guard.ptr, guard.bytes, cudaMemcpyDeviceToHost),
          "cudaMemcpy workspace guard");
      for (size_t i = 0; i < host.size(); ++i) {
        if (host[i] != kIntegrityGuardByte) {
          std::fprintf(
              stderr,
              "[integrity] phase=corrupt guard=%s offset=%zu expected=0x%02x found=0x%02x\n",
              guard.name,
              i,
              static_cast<unsigned>(kIntegrityGuardByte),
              static_cast<unsigned>(host[i]));
          std::fflush(stderr);
          TVM_FFI_THROW(RuntimeError)
              << "Workspace guard corrupted for " << guard.name << " at offset " << i;
        }
      }
    }
  }

  void zero_all(const char* name) {
    zero_device_region(base_, capacity_, stream_, name);
  }

 private:
  static constexpr size_t kAlignment = 256;
  DeviceBuffer owned_buffer_;
  uint8_t* base_ = nullptr;
  size_t capacity_ = 0;
  size_t offset_ = 0;
  bool integrity_diagnostic_ = false;
  cudaStream_t stream_ = nullptr;
  std::vector<IntegrityGuardRegion> guards_;
};

void add_aligned_bytes(
    size_t* total,
    int64_t elements,
    size_t element_size,
    const char* name,
    bool integrity_diagnostic = false) {
  *total = align_up(*total, 256);
  const size_t bytes = checked_bytes(elements, element_size, name);
  if (bytes > std::numeric_limits<size_t>::max() - *total) {
    TVM_FFI_THROW(OverflowError) << name << " workspace is too large";
  }
  *total += bytes;
  if (integrity_diagnostic) {
    if (kIntegrityGuardBytes > std::numeric_limits<size_t>::max() - *total) {
      TVM_FFI_THROW(OverflowError) << name << " integrity guard is too large";
    }
    *total += kIntegrityGuardBytes;
  }
}

bool env_flag_is_one(const char* name) {
  const char* value = std::getenv(name);
  return value != nullptr && value[0] == '1' && value[1] == '\0';
}

bool cutlass92_stateless_diagnostic_enabled() {
  return env_flag_is_one(kEnableCutlass92StatelessDiagnosticEnv);
}

bool cutlass92_path_trace_enabled() {
  return env_flag_is_one(kEnableCutlass92PathTraceEnv);
}

bool reusable_temp_diagnostic_enabled() {
  return env_flag_is_one(kEnableReusableTempDiagnosticEnv);
}

bool cutlass92_stage_validation_diagnostic_enabled() {
  return env_flag_is_one(kEnableCutlass92StageValidationDiagnosticEnv);
}

struct TempStateInitConfig {
  bool enabled = false;
  bool workspace = false;
  bool row_owner = false;
  bool cutlass_launch = false;
};

struct Cutlass92PerturbationConfig {
  bool enabled = false;
  bool full_stage_validation = false;
  bool metadata_hostcopy_sync = false;
  bool gemm1_reference_compare = false;
  bool gemm2_reference_compare = false;
  bool sync_after_metadata = false;
  bool sync_after_gemm1 = false;
  bool sync_after_gemm2 = false;
};

struct Gemm2RefComponentConfig {
  bool enabled = false;
  bool prepare_reference = false;
  bool compare_tail = false;
};

struct PrepareReferenceComponentConfig {
  bool enabled = false;
  bool zero_output_fp32 = false;
  bool fallback_gemm1_prepare = false;
  bool fallback_gemm2_accumulation = false;
};

bool env_list_contains_token(const char* value, const char* token) {
  if (value == nullptr || token == nullptr || token[0] == '\0') {
    return false;
  }
  const size_t token_len = std::strlen(token);
  const char* cursor = value;
  while ((cursor = std::strstr(cursor, token)) != nullptr) {
    const bool left_ok = (cursor == value) || cursor[-1] == ',';
    const char right = cursor[token_len];
    const bool right_ok = right == '\0' || right == ',';
    if (left_ok && right_ok) {
      return true;
    }
    cursor += token_len;
  }
  return false;
}

TempStateInitConfig temp_state_init_config() {
  TempStateInitConfig config;
  config.enabled = env_flag_is_one(kEnableFullTempStateInitDiagnosticEnv);
  if (!config.enabled) {
    return config;
  }
  const char* families = std::getenv(kTempStateInitFamiliesEnv);
  if (families == nullptr || families[0] == '\0') {
    config.workspace = true;
    config.row_owner = true;
    config.cutlass_launch = true;
    return config;
  }
  config.workspace = env_list_contains_token(families, "workspace");
  config.row_owner = env_list_contains_token(families, "row_owner");
  config.cutlass_launch = env_list_contains_token(families, "cutlass_launch");
  return config;
}

Cutlass92PerturbationConfig cutlass92_perturbation_config() {
  Cutlass92PerturbationConfig config;
  config.full_stage_validation = cutlass92_stage_validation_diagnostic_enabled();
  const bool bisection_enabled = env_flag_is_one(kEnableCutlass92PerturbationBisectionDiagnosticEnv);
  if (!config.full_stage_validation && !bisection_enabled) {
    return config;
  }
  const char* subset = std::getenv(kCutlass92PerturbationSubsetEnv);
  const bool enable_all = config.full_stage_validation || subset == nullptr || subset[0] == '\0';
  config.metadata_hostcopy_sync = enable_all || env_list_contains_token(subset, "metadata_hostcopy");
  config.gemm1_reference_compare = enable_all || env_list_contains_token(subset, "gemm1_ref");
  config.gemm2_reference_compare = enable_all || env_list_contains_token(subset, "gemm2_ref");
  config.sync_after_metadata = enable_all || env_list_contains_token(subset, "sync_after_metadata");
  config.sync_after_gemm1 = enable_all || env_list_contains_token(subset, "sync_after_gemm1");
  config.sync_after_gemm2 = enable_all || env_list_contains_token(subset, "sync_after_gemm2");
  config.enabled = config.metadata_hostcopy_sync || config.gemm1_reference_compare ||
      config.gemm2_reference_compare || config.sync_after_metadata || config.sync_after_gemm1 ||
      config.sync_after_gemm2;
  return config;
}

Gemm2RefComponentConfig gemm2_ref_component_config() {
  Gemm2RefComponentConfig config;
  if (!env_flag_is_one(kEnableGemm2RefComponentBisectionDiagnosticEnv)) {
    return config;
  }
  const char* subset = std::getenv(kGemm2RefComponentSubsetEnv);
  const bool enable_all = subset == nullptr || subset[0] == '\0';
  config.prepare_reference =
      enable_all || env_list_contains_token(subset, "prepare_reference") ||
      env_list_contains_token(subset, "fallback_accumulation");
  config.compare_tail = enable_all || env_list_contains_token(subset, "compare_tail");
  config.enabled = config.prepare_reference || config.compare_tail;
  return config;
}

PrepareReferenceComponentConfig prepare_reference_component_config() {
  PrepareReferenceComponentConfig config;
  if (!env_flag_is_one(kEnablePrepareReferenceComponentBisectionDiagnosticEnv)) {
    return config;
  }
  const char* subset = std::getenv(kPrepareReferenceComponentSubsetEnv);
  const bool enable_all = subset == nullptr || subset[0] == '\0';
  config.zero_output_fp32 =
      enable_all || env_list_contains_token(subset, "zero_output") ||
      env_list_contains_token(subset, "zero_output_fp32");
  const bool gemm1_selected =
      enable_all || env_list_contains_token(subset, "fallback_gemm1") ||
      env_list_contains_token(subset, "gemm1_prepare");
  const bool gemm2_selected =
      enable_all || env_list_contains_token(subset, "fallback_gemm2_accumulation") ||
      env_list_contains_token(subset, "gemm2_accumulation") ||
      env_list_contains_token(subset, "gemm2_accum");
  config.fallback_gemm2_accumulation = gemm2_selected;
  config.fallback_gemm1_prepare = gemm1_selected || gemm2_selected;
  config.enabled =
      config.zero_output_fp32 || config.fallback_gemm1_prepare || config.fallback_gemm2_accumulation;
  return config;
}

bool invocation_integrity_diagnostic_enabled() {
  return env_flag_is_one(kEnableInvocationIntegrityDiagnosticEnv);
}

bool private_stream_execution_diagnostic_enabled() {
  return env_flag_is_one(kEnablePrivateStreamExecutionDiagnosticEnv);
}

bool device_wide_fence_diagnostic_enabled() {
  return env_flag_is_one(kEnableDeviceWideFenceDiagnosticEnv);
}

bool post_gemm2_materialization_diagnostic_enabled() {
  return env_flag_is_one(kEnablePostGemm2MaterializationDiagnosticEnv);
}

bool fp32_finalization_diagnostic_enabled() {
  return env_flag_is_one(kEnableFp32FinalizationDiagnosticEnv);
}

bool device_supports_cutlass92(int device_index);

bool short_cutlass92_runtime_enabled(int64_t seq_len, int32_t device_index) {
  if (seq_len <= 1 || seq_len > kCompactScalarSmallSeqLenGate) {
    return false;
  }
  if (env_flag_is_one(kDisableCutlass92Env)) {
    return false;
  }
#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
  return device_supports_cutlass92(device_index);
#else
  (void)device_index;
  return false;
#endif
}

bool promoted_reusable_temp_enabled(bool cutlass_runtime_active, bool diagnostic_override) {
  return cutlass_runtime_active || diagnostic_override;
}

bool promoted_fp32_finalization_enabled(bool cutlass_runtime_active, bool diagnostic_override) {
  return cutlass_runtime_active || diagnostic_override;
}

bool should_use_compact_scalar_path(int64_t seq_len) {
  if (env_flag_is_one(kDisableCompactScalarEnv)) {
    return false;
  }
  if (seq_len > 0 && env_flag_is_one(kEnableCompactScalarEnv)) {
    return true;
  }
  if (seq_len > kCompactScalarSmallSeqLenGate && seq_len <= kCompactScalarSeqLenGate) {
    return true;
  }
#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
  if (seq_len > kCompactScalarSeqLenGate) {
    return true;
  }
#endif
  return seq_len > 0 && env_flag_is_one(kEnableCompactScalarSmallSeqEnv);
}

void check_dtype(
    const tvm::ffi::TensorView& tensor,
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

void check_rank(const tvm::ffi::TensorView& tensor, int32_t rank, const char* name) {
  if (tensor.ndim() != rank) {
    TVM_FFI_THROW(ValueError) << name << " must have rank " << rank << ", got " << tensor.ndim();
  }
}

void check_cuda_tensor(const tvm::ffi::TensorView& tensor, const char* name) {
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

void check_same_device(
    const tvm::ffi::TensorView& reference,
    const tvm::ffi::TensorView& tensor,
    const char* name) {
  const DLDevice ref_device = reference.device();
  const DLDevice device = tensor.device();
  if (device.device_type != ref_device.device_type || device.device_id != ref_device.device_id) {
    TVM_FFI_THROW(ValueError) << name << " must be on the same CUDA device as routing_logits";
  }
}

void check_shape1(const tvm::ffi::TensorView& tensor, int64_t dim0, const char* name) {
  check_rank(tensor, 1, name);
  if (tensor.size(0) != dim0) {
    TVM_FFI_THROW(ValueError) << name << " has incorrect shape";
  }
}

void check_shape2(
    const tvm::ffi::TensorView& tensor,
    int64_t dim0,
    int64_t dim1,
    const char* name) {
  check_rank(tensor, 2, name);
  if (tensor.size(0) != dim0 || tensor.size(1) != dim1) {
    TVM_FFI_THROW(ValueError) << name << " has incorrect shape";
  }
}

void check_shape3(
    const tvm::ffi::TensorView& tensor,
    int64_t dim0,
    int64_t dim1,
    int64_t dim2,
    const char* name) {
  check_rank(tensor, 3, name);
  if (tensor.size(0) != dim0 || tensor.size(1) != dim1 || tensor.size(2) != dim2) {
    TVM_FFI_THROW(ValueError) << name << " has incorrect shape";
  }
}

void prepare_tensor(
    const tvm::ffi::TensorView& reference,
    const tvm::ffi::TensorView& tensor,
    const char* name) {
  check_cuda_tensor(tensor, name);
  check_same_device(reference, tensor, name);
}

void validate_inputs(
    const tvm::ffi::TensorView& routing_logits,
    const tvm::ffi::TensorView& routing_bias,
    const tvm::ffi::TensorView& hidden_states,
    const tvm::ffi::TensorView& hidden_states_scale,
    const tvm::ffi::TensorView& gemm1_weights,
    const tvm::ffi::TensorView& gemm1_weights_scale,
    const tvm::ffi::TensorView& gemm2_weights,
    const tvm::ffi::TensorView& gemm2_weights_scale,
    const tvm::ffi::TensorView& output) {
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
  check_shape3(gemm1_weights_scale, kNumLocalExperts, kGemm1OutBlocks, kHiddenBlocks, "gemm1_weights_scale");
  check_shape3(gemm2_weights, kNumLocalExperts, kHiddenSize, kIntermediateSize, "gemm2_weights");
  check_shape3(gemm2_weights_scale, kNumLocalExperts, kHiddenBlocks, kIntermediateBlocks, "gemm2_weights_scale");
  check_shape2(output, seq_len, kHiddenSize, "output");

  if (seq_len > std::numeric_limits<int32_t>::max() / kTopK) {
    TVM_FFI_THROW(ValueError) << "seq_len is too large";
  }
  if (seq_len > std::numeric_limits<int32_t>::max() / kHiddenSize) {
    TVM_FFI_THROW(ValueError) << "output element count is too large";
  }
}

__device__ __forceinline__ float fp8_e4m3_to_float(const uint8_t byte) {
  __nv_fp8_e4m3 value;
  memcpy(&value, &byte, 1);
  return static_cast<float>(value);
}

__device__ __forceinline__ uint8_t float_to_fp8_e4m3_byte(float value) {
  const __nv_fp8_e4m3 fp8_value(value);
  uint8_t byte;
  memcpy(&byte, &fp8_value, 1);
  return byte;
}

__host__ __device__ __forceinline__ uint8_t ue8m0_nearest_power2_storage(float scale) {
  const float abs_scale = fabsf(scale);
  if (abs_scale == 0.0f) {
    return 127;
  }
  const float exponent_f = nearbyintf(log2f(abs_scale));
  int32_t storage = static_cast<int32_t>(exponent_f) + 127;
  storage = storage < 0 ? 0 : storage;
  storage = storage > 254 ? 254 : storage;
  return static_cast<uint8_t>(storage);
}

__host__ __device__ __forceinline__ uint8_t ue8m0_ceiling_power2_storage(float scale) {
  const float abs_scale = fabsf(scale);
  if (abs_scale == 0.0f) {
    return 127;
  }
  const float exponent_f = ceilf(log2f(abs_scale));
  int32_t storage = static_cast<int32_t>(exponent_f) + 127;
  storage = storage < 0 ? 0 : storage;
  storage = storage > 254 ? 254 : storage;
  return static_cast<uint8_t>(storage);
}

__host__ __device__ __forceinline__ float ue8m0_storage_to_power2(uint8_t storage) {
  return exp2f(static_cast<float>(static_cast<int32_t>(storage) - 127));
}

#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
using Cutlass92ProblemShape = cutlass::gemm::MoEProblemShape<cute::Shape<int,int,int>>;
using Cutlass92ElementInput = cutlass::float_e4m3_t;
using Cutlass92ElementSF = cutlass::float_ue8m0_t;
using Cutlass92ElementC = cutlass::bfloat16_t;
using Cutlass92ElementA = cutlass::mx_float8_t<Cutlass92ElementInput>;
using Cutlass92LayoutA = cutlass::layout::RowMajor;
constexpr int Cutlass92AlignmentA = 16;
using Cutlass92ElementB = cutlass::mx_float8_t<Cutlass92ElementInput>;
using Cutlass92LayoutB = cutlass::layout::ColumnMajor;
constexpr int Cutlass92AlignmentB = 16;
using Cutlass92LayoutC = cutlass::layout::ColumnMajor;
constexpr int Cutlass92AlignmentC = 128 / cutlass::sizeof_bits<Cutlass92ElementC>::value;
constexpr int Cutlass92AlignmentD = Cutlass92AlignmentC;
using Cutlass92ElementAccumulator = float;
using Cutlass92ArchTag = cutlass::arch::Sm100;
using Cutlass92OperatorClass = cutlass::arch::OpClassBlockScaledTensorOp;
using Cutlass92ClusterShape = cute::Shape<int32_t,int32_t,cute::_1>;

struct Cutlass92MMA1SMConfig {
  using MmaTileShape = cute::Shape<cute::_128,cute::_256,cute::_128>;
  using KernelSchedule = cutlass::gemm::KernelPtrArrayTmaWarpSpecialized1SmMxf8f6f4Sm100;
  using EpilogueSchedule = cutlass::epilogue::PtrArrayTmaWarpSpecialized1Sm;
};

struct Cutlass92MMA2SMConfig {
  using MmaTileShape = cute::Shape<cute::_256,cute::_256,cute::_128>;
  using KernelSchedule = cutlass::gemm::KernelPtrArrayTmaWarpSpecialized2SmMxf8f6f4Sm100;
  using EpilogueSchedule = cutlass::epilogue::PtrArrayTmaWarpSpecialized2Sm;
};

template <typename MmaConfig>
using Cutlass92CollectiveEpilogueFor = typename cutlass::epilogue::collective::CollectiveBuilder<
    Cutlass92ArchTag,
    Cutlass92OperatorClass,
    typename MmaConfig::MmaTileShape,
    Cutlass92ClusterShape,
    cute::Shape<cute::_128,cute::_64>,
    Cutlass92ElementAccumulator,
    Cutlass92ElementAccumulator,
    Cutlass92ElementC,
    Cutlass92LayoutC*,
    Cutlass92AlignmentC,
    Cutlass92ElementC,
    Cutlass92LayoutC*,
    Cutlass92AlignmentD,
    typename MmaConfig::EpilogueSchedule>::CollectiveOp;

template <typename MmaConfig>
using Cutlass92CollectiveMainloopFor = typename cutlass::gemm::collective::CollectiveBuilder<
    Cutlass92ArchTag,
    Cutlass92OperatorClass,
    Cutlass92ElementA,
    Cutlass92LayoutA,
    Cutlass92AlignmentA,
    Cutlass92ElementB,
    Cutlass92LayoutB*,
    Cutlass92AlignmentB,
    Cutlass92ElementAccumulator,
    typename MmaConfig::MmaTileShape,
    Cutlass92ClusterShape,
    cutlass::gemm::collective::StageCountAutoCarveout<
        static_cast<int>(sizeof(typename Cutlass92CollectiveEpilogueFor<MmaConfig>::SharedStorage))>,
    typename MmaConfig::KernelSchedule>::CollectiveOp;

template <typename MmaConfig>
using Cutlass92GemmKernelFor = cutlass::gemm::kernel::GemmUniversal<
    Cutlass92ProblemShape,
    Cutlass92CollectiveMainloopFor<MmaConfig>,
    Cutlass92CollectiveEpilogueFor<MmaConfig>>;

template <typename MmaConfig>
using Cutlass92GemmFor = cutlass::gemm::device::GemmUniversalAdapter<Cutlass92GemmKernelFor<MmaConfig>>;

using Cutlass92Gemm1SM = Cutlass92GemmFor<Cutlass92MMA1SMConfig>;
using Cutlass92Gemm2SM = Cutlass92GemmFor<Cutlass92MMA2SMConfig>;
using Cutlass92LayoutGemm = Cutlass92Gemm1SM;
using Cutlass92StrideB = typename Cutlass92LayoutGemm::GemmKernel::InternalStrideB;
using Cutlass92LayoutSFA = typename Cutlass92LayoutGemm::GemmKernel::CollectiveMainloop::InternalLayoutSFA;
using Cutlass92LayoutSFB = typename Cutlass92LayoutGemm::GemmKernel::CollectiveMainloop::InternalLayoutSFB;
using Cutlass92BlkScaledConfig =
    typename Cutlass92LayoutGemm::GemmKernel::CollectiveMainloop::Sm1xxBlkScaledConfig;

int64_t cutlass92_sfb_storage_elements(int32_t m, int32_t n, int32_t k) {
  const int32_t safe_n = n > 0 ? n : 1;
  auto layout = Cutlass92BlkScaledConfig::tile_atom_to_shape_SFB(cute::make_shape(m, safe_n, k, 1));
  return static_cast<int64_t>(cute::size(cute::filter_zeros(layout)));
}

int32_t round_up_cutlass92_n(int32_t n) {
  constexpr int32_t kAlignment = 16;
  return ((n + kAlignment - 1) / kAlignment) * kAlignment;
}
#endif

__global__ void route_topk_kernel(
    const float* __restrict__ routing_logits,
    const __nv_bfloat16* __restrict__ routing_bias,
    int32_t* __restrict__ topk_idx,
    float* __restrict__ topk_weight,
    int32_t local_expert_offset,
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

__global__ void route_topk_short_kernel(
    const float* __restrict__ routing_logits,
    const __nv_bfloat16* __restrict__ routing_bias,
    int32_t* __restrict__ topk_idx,
    float* __restrict__ topk_weight,
    float routed_scaling_factor,
    int32_t seq_len) {
  const int32_t token = static_cast<int32_t>(blockIdx.x);
  const int32_t lane = static_cast<int32_t>(threadIdx.x);
  if (token >= seq_len || lane >= 32) {
    return;
  }

  __shared__ float biased_scores[kNumExpertsGlobal];
  __shared__ float scores[kNumExpertsGlobal];
  for (int32_t expert = lane; expert < kNumExpertsGlobal; expert += 32) {
    const float logit = routing_logits[token * kNumExpertsGlobal + expert];
    const float score = 1.0f / (1.0f + expf(-logit));
    scores[expert] = score;
    biased_scores[expert] = score + __bfloat162float(routing_bias[expert]);
  }
  __syncthreads();

  if (lane != 0) {
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

__global__ void build_short_compact_metadata_kernel(
    const int32_t* __restrict__ topk_idx,
    const float* __restrict__ topk_weight,
    int32_t* __restrict__ counts_by_expert,
    int32_t* __restrict__ starts_by_expert,
    int32_t* __restrict__ offsets_by_expert,
    int32_t* __restrict__ compact_slot_ids,
    int32_t* __restrict__ slot_to_compact_row,
    float* __restrict__ compact_weights,
    int32_t* __restrict__ total_local_slots,
    int32_t local_expert_offset,
    int32_t total_slots) {
  if (blockIdx.x != 0 || threadIdx.x != 0) {
    return;
  }

  int32_t counts[kNumLocalExperts];
  int32_t next_row[kNumLocalExperts];
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    counts[expert] = 0;
  }

  for (int32_t slot = 0; slot < total_slots; ++slot) {
    slot_to_compact_row[slot] = kInvalidToken;
    const int32_t local_expert = topk_idx[slot] - local_expert_offset;
    if (local_expert >= 0 && local_expert < kNumLocalExperts) {
      ++counts[local_expert];
    }
  }

  int32_t total_rows = 0;
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    counts_by_expert[expert] = counts[expert];
    starts_by_expert[expert] = total_rows;
    next_row[expert] = total_rows;
    total_rows += counts[expert];
    offsets_by_expert[expert] = total_rows;
  }
  total_local_slots[0] = total_rows;

  for (int32_t slot = 0; slot < total_slots; ++slot) {
    const int32_t local_expert = topk_idx[slot] - local_expert_offset;
    if (local_expert < 0 || local_expert >= kNumLocalExperts) {
      continue;
    }

    const int32_t row = next_row[local_expert]++;
    compact_slot_ids[row] = slot;
    compact_weights[row] = topk_weight[slot];
    slot_to_compact_row[slot] = row;
  }
}

__global__ void build_short_cutlass92_metadata_kernel(
    const int32_t* __restrict__ topk_idx,
    const float* __restrict__ topk_weight,
    int32_t* __restrict__ counts_by_expert,
    int32_t* __restrict__ starts_by_expert,
    int32_t* __restrict__ offsets_by_expert,
    int32_t* __restrict__ compact_slot_ids,
    int32_t* __restrict__ slot_to_compact_row,
    float* __restrict__ compact_weights,
    int32_t* __restrict__ total_local_slots,
    int32_t* __restrict__ compact_row_to_local_expert,
    int32_t* __restrict__ compact_row_to_expert_row,
    int32_t local_expert_offset,
    int32_t total_slots) {
  if (blockIdx.x != 0 || threadIdx.x != 0) {
    return;
  }

  int32_t counts[kNumLocalExperts];
  int32_t next_row[kNumLocalExperts];
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    counts[expert] = 0;
  }

  for (int32_t slot = 0; slot < total_slots; ++slot) {
    slot_to_compact_row[slot] = kInvalidToken;
    const int32_t local_expert = topk_idx[slot] - local_expert_offset;
    if (local_expert >= 0 && local_expert < kNumLocalExperts) {
      ++counts[local_expert];
    }
  }

  int32_t total_rows = 0;
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    counts_by_expert[expert] = counts[expert];
    starts_by_expert[expert] = total_rows;
    next_row[expert] = total_rows;
    total_rows += counts[expert];
    offsets_by_expert[expert] = total_rows;
  }
  total_local_slots[0] = total_rows;

  for (int32_t slot = 0; slot < total_slots; ++slot) {
    const int32_t local_expert = topk_idx[slot] - local_expert_offset;
    if (local_expert < 0 || local_expert >= kNumLocalExperts) {
      continue;
    }
    const int32_t row = next_row[local_expert]++;
    compact_slot_ids[row] = slot;
    compact_weights[row] = topk_weight[slot];
    slot_to_compact_row[slot] = row;
    compact_row_to_local_expert[row] = local_expert;
    compact_row_to_expert_row[row] = row - starts_by_expert[local_expert];
  }
}

__global__ void build_local_expert_bins_kernel(
    const int32_t* __restrict__ topk_idx,
    const float* __restrict__ topk_weight,
    int32_t* __restrict__ slot_ids_by_expert,
    float* __restrict__ weights_by_expert,
    int32_t* __restrict__ counts_by_expert,
    int32_t* __restrict__ slot_to_compact_row,
    int32_t local_expert_offset,
    int32_t total_slots) {
  const int32_t slot = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (slot >= total_slots) {
    return;
  }

  slot_to_compact_row[slot] = kInvalidToken;
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (local_expert < 0 || local_expert >= kNumLocalExperts) {
    return;
  }

  const int32_t position = atomicAdd(&counts_by_expert[local_expert], 1);
  const int64_t out = static_cast<int64_t>(local_expert) * total_slots + position;
  slot_ids_by_expert[out] = slot;
  weights_by_expert[out] = topk_weight[slot];
}

__global__ void build_expert_offsets_kernel(
    const int32_t* __restrict__ counts_by_expert,
    int32_t* __restrict__ starts_by_expert,
    int32_t* __restrict__ offsets_by_expert,
    int32_t* __restrict__ total_local_slots) {
  int32_t sum = 0;
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    starts_by_expert[expert] = sum;
    sum += counts_by_expert[expert];
    offsets_by_expert[expert] = sum;
  }
  total_local_slots[0] = sum;
}

__global__ void compact_expert_metadata_kernel(
    const int32_t* __restrict__ slot_ids_by_expert,
    const float* __restrict__ weights_by_expert,
    const int32_t* __restrict__ counts_by_expert,
    const int32_t* __restrict__ starts_by_expert,
    int32_t* __restrict__ compact_slot_ids,
    int32_t* __restrict__ slot_to_compact_row,
    float* __restrict__ compact_weights,
    int32_t total_slots) {
  const int32_t expert = static_cast<int32_t>(blockIdx.y);
  const int32_t position = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (expert >= kNumLocalExperts || position >= counts_by_expert[expert]) {
    return;
  }

  const int32_t dst = starts_by_expert[expert] + position;
  const int64_t src = static_cast<int64_t>(expert) * total_slots + position;
  const int32_t slot = slot_ids_by_expert[src];
  compact_slot_ids[dst] = slot;
  slot_to_compact_row[slot] = dst;
  compact_weights[dst] = weights_by_expert[src];
}

__global__ void build_cutlass92_row_owner_metadata_kernel(
    const int32_t* __restrict__ counts_by_expert,
    const int32_t* __restrict__ starts_by_expert,
    int32_t* __restrict__ compact_row_to_local_expert,
    int32_t* __restrict__ compact_row_to_expert_row) {
  const int32_t expert = static_cast<int32_t>(blockIdx.y);
  const int32_t position = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (expert >= kNumLocalExperts || position >= counts_by_expert[expert]) {
    return;
  }
  const int32_t row = starts_by_expert[expert] + position;
  compact_row_to_local_expert[row] = expert;
  compact_row_to_expert_row[row] = position;
}

__device__ __forceinline__ void set_debug_status(int32_t* status, int32_t code) {
  atomicCAS(status, 0, code);
}

__global__ void validate_compact_metadata_kernel(
    const int32_t* __restrict__ topk_idx,
    const int32_t* __restrict__ compact_slot_ids,
    const int32_t* __restrict__ slot_to_compact_row,
    const int32_t* __restrict__ total_local_slots,
    int32_t* __restrict__ status,
    int32_t local_expert_offset,
    int32_t total_slots) {
  const int32_t slot = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  const int32_t live_rows = total_local_slots[0];
  if (slot == 0 && (live_rows < 0 || live_rows > total_slots)) {
    set_debug_status(status, 1);
  }
  if (slot >= total_slots) {
    return;
  }

  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  const bool is_local = local_expert >= 0 && local_expert < kNumLocalExperts;
  const int32_t row = slot_to_compact_row[slot];
  if (is_local) {
    if (row < 0 || row >= live_rows) {
      set_debug_status(status, 2);
      return;
    }
    if (compact_slot_ids[row] != slot) {
      set_debug_status(status, 3);
    }
  } else if (row != kInvalidToken) {
    set_debug_status(status, 4);
  }

  if (slot < live_rows) {
    const int32_t row_slot = compact_slot_ids[slot];
    if (row_slot < 0 || row_slot >= total_slots) {
      set_debug_status(status, 5);
      return;
    }
    if (slot_to_compact_row[row_slot] != slot) {
      set_debug_status(status, 6);
    }
  }
}

__global__ void compact_hidden_bf16_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const int32_t* __restrict__ compact_slot_ids,
    const int32_t* __restrict__ total_local_slots,
    __nv_bfloat16* __restrict__ compact_hidden,
    int32_t seq_len) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t tile = static_cast<int32_t>(blockIdx.y);
  const int32_t lane = static_cast<int32_t>(threadIdx.x);
  if (lane >= kCompactHiddenThreads || row >= total_local_slots[0]) {
    return;
  }

  const int32_t slot = compact_slot_ids[row];
  const int32_t token = slot / kTopK;
  __shared__ float scales[kCompactHiddenBlocksPerTile];
  if (token >= 0 && token < seq_len && lane < kCompactHiddenBlocksPerTile) {
    const int32_t load_block = tile * kCompactHiddenBlocksPerTile + lane;
    scales[lane] = hidden_states_scale[load_block * seq_len + token];
  }
  __syncthreads();

#pragma unroll
  for (int32_t elem = 0; elem < kCompactHiddenElemsPerThread; ++elem) {
    const int32_t hidden = tile * kCompactHiddenTileSize + elem * kCompactHiddenThreads + lane;
    const int64_t out = static_cast<int64_t>(row) * kHiddenSize + hidden;
    if (token < 0 || token >= seq_len) {
      compact_hidden[out] = __float2bfloat16(0.0f);
      continue;
    }

    const int32_t tile_block = hidden / kBlockSize - tile * kCompactHiddenBlocksPerTile;
    const float value =
        fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) *
        scales[tile_block];
    compact_hidden[out] = __float2bfloat16(value);
  }
}

#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
__global__ void pack_cutlass92_gemm1_weights_kernel(
    const uint8_t* __restrict__ gemm1_weights,
    const float* __restrict__ gemm1_weights_scale,
    uint8_t* __restrict__ packed_a,
    uint8_t* __restrict__ packed_sfa) {
  const int64_t idx = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(kNumLocalExperts) * kGemm1OutSize * kHiddenSize;
  if (idx >= total) {
    return;
  }

  const int32_t hidden = static_cast<int32_t>(idx % kHiddenSize);
  const int64_t row_idx = idx / kHiddenSize;
  const int32_t m = static_cast<int32_t>(row_idx % kGemm1OutSize);
  const int32_t expert = static_cast<int32_t>(row_idx / kGemm1OutSize);
  const int32_t scale_idx =
      (expert * kGemm1OutBlocks + (m / kBlockSize)) * kHiddenBlocks + (hidden / kBlockSize);
  const float scale = gemm1_weights_scale[scale_idx];
  const uint8_t q_storage = ue8m0_nearest_power2_storage(scale);
  const float q = ue8m0_storage_to_power2(q_storage);
  const float residual = scale == 0.0f ? 0.0f : fabsf(scale) / q;
  const float sign = scale < 0.0f ? -1.0f : 1.0f;
  const float adapted = fp8_e4m3_to_float(gemm1_weights[idx]) * sign * residual;

  packed_a[idx] = float_to_fp8_e4m3_byte(adapted);

  auto layout_sfa = Cutlass92BlkScaledConfig::tile_atom_to_shape_SFA(
      cute::make_shape(kGemm1OutSize, 1, kHiddenSize, kNumLocalExperts));
  packed_sfa[layout_sfa(m, hidden, expert)] = q_storage;
}

__global__ void init_cutlass92_gemm1_ptrs_kernel(
    const int32_t* __restrict__ starts_by_expert,
    uint8_t* __restrict__ packed_b,
    uint8_t* __restrict__ packed_sfb,
    __nv_bfloat16* __restrict__ gemm1_out,
    uintptr_t* __restrict__ ptr_b,
    uintptr_t* __restrict__ ptr_sfb,
    uintptr_t* __restrict__ ptr_c,
    uintptr_t* __restrict__ ptr_d,
    int64_t sfb_stride,
    int32_t n_cutlass) {
  const int32_t expert = static_cast<int32_t>(threadIdx.x);
  if (expert >= kNumLocalExperts) {
    return;
  }
  const int64_t start = static_cast<int64_t>(starts_by_expert[expert]);
  ptr_b[expert] =
      reinterpret_cast<uintptr_t>(packed_b + static_cast<int64_t>(expert) * n_cutlass * kHiddenSize);
  ptr_sfb[expert] = reinterpret_cast<uintptr_t>(packed_sfb + static_cast<int64_t>(expert) * sfb_stride);
  ptr_c[expert] = 0;
  ptr_d[expert] = reinterpret_cast<uintptr_t>(gemm1_out + start * kGemm1OutSize);
}

__global__ void pack_cutlass92_gemm1_activation_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const int32_t* __restrict__ compact_slot_ids,
    const int32_t* __restrict__ compact_row_to_local_expert,
    const int32_t* __restrict__ compact_row_to_expert_row,
    const int32_t* __restrict__ total_local_slots,
    uint8_t* __restrict__ packed_b,
    uint8_t* __restrict__ packed_sfb,
    int64_t sfb_stride,
    int32_t n_cutlass,
    int32_t seq_len) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t tile = static_cast<int32_t>(blockIdx.y);
  const int32_t lane = static_cast<int32_t>(threadIdx.x);
  if (lane >= kCompactHiddenThreads || row >= total_local_slots[0]) {
    return;
  }

  const int32_t expert = compact_row_to_local_expert[row];
  const int32_t n = compact_row_to_expert_row[row];
  if (expert < 0 || expert >= kNumLocalExperts || n < 0 || n >= n_cutlass) {
    return;
  }
  const int32_t slot = compact_slot_ids[row];
  const int32_t token = slot / kTopK;

  auto stride_b = cutlass::make_cute_packed_stride(
      Cutlass92StrideB{},
      {n_cutlass, static_cast<int32_t>(kHiddenSize), 1});
  auto layout_b =
      cute::make_layout(cute::make_shape(n_cutlass, static_cast<int32_t>(kHiddenSize), 1), stride_b);
  auto layout_sfb =
      Cutlass92BlkScaledConfig::tile_atom_to_shape_SFB(cute::make_shape(
          static_cast<int32_t>(kGemm1OutSize),
          n_cutlass,
          static_cast<int32_t>(kHiddenSize),
          1));
  uint8_t* expert_b = packed_b + static_cast<int64_t>(expert) * n_cutlass * kHiddenSize;
  uint8_t* expert_sfb = packed_sfb + static_cast<int64_t>(expert) * sfb_stride;

#pragma unroll
  for (int32_t elem = 0; elem < kCompactHiddenElemsPerThread; ++elem) {
    const int32_t hidden = tile * kCompactHiddenTileSize + elem * kCompactHiddenThreads + lane;
    if (hidden >= kHiddenSize) {
      continue;
    }

    uint8_t adapted_byte = 0;
    uint8_t q_storage = 127;
    if (token >= 0 && token < seq_len) {
      const float scale = hidden_states_scale[(hidden / kBlockSize) * seq_len + token];
      q_storage = ue8m0_nearest_power2_storage(scale);
      const float q = ue8m0_storage_to_power2(q_storage);
      const float residual = scale == 0.0f ? 0.0f : fabsf(scale) / q;
      const float sign = scale < 0.0f ? -1.0f : 1.0f;
      const float value =
          fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) * sign * residual;
      adapted_byte = float_to_fp8_e4m3_byte(value);
    }

    expert_b[layout_b(n, hidden, 0)] = adapted_byte;
    expert_sfb[layout_sfb(n, hidden, 0)] = q_storage;
  }
}

__global__ void pack_cutlass92_gemm1_activation_short_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const int32_t* __restrict__ compact_slot_ids,
    const int32_t* __restrict__ compact_row_to_local_expert,
    const int32_t* __restrict__ compact_row_to_expert_row,
    const int32_t* __restrict__ total_local_slots,
    uint8_t* __restrict__ packed_b,
    uint8_t* __restrict__ packed_sfb,
    int64_t sfb_stride,
    int32_t n_cutlass,
    int32_t seq_len) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t tile = static_cast<int32_t>(blockIdx.y);
  const int32_t lane = static_cast<int32_t>(threadIdx.x);
  if (lane >= kShortCutlassGemm1PackThreads || row >= total_local_slots[0]) {
    return;
  }

  const int32_t expert = compact_row_to_local_expert[row];
  const int32_t n = compact_row_to_expert_row[row];
  if (expert < 0 || expert >= kNumLocalExperts || n < 0 || n >= n_cutlass) {
    return;
  }
  const int32_t slot = compact_slot_ids[row];
  const int32_t token = slot / kTopK;

  auto stride_b = cutlass::make_cute_packed_stride(
      Cutlass92StrideB{},
      {n_cutlass, static_cast<int32_t>(kHiddenSize), 1});
  auto layout_b =
      cute::make_layout(cute::make_shape(n_cutlass, static_cast<int32_t>(kHiddenSize), 1), stride_b);
  auto layout_sfb =
      Cutlass92BlkScaledConfig::tile_atom_to_shape_SFB(cute::make_shape(
          static_cast<int32_t>(kGemm1OutSize),
          n_cutlass,
          static_cast<int32_t>(kHiddenSize),
          1));
  uint8_t* expert_b = packed_b + static_cast<int64_t>(expert) * n_cutlass * kHiddenSize;
  uint8_t* expert_sfb = packed_sfb + static_cast<int64_t>(expert) * sfb_stride;

#pragma unroll
  for (int32_t elem = 0; elem < kShortCutlassGemm1PackElemsPerThread; ++elem) {
    const int32_t hidden = tile * kCompactHiddenTileSize + elem * kShortCutlassGemm1PackThreads + lane;
    if (hidden >= kHiddenSize) {
      continue;
    }

    uint8_t adapted_byte = 0;
    uint8_t q_storage = 127;
    if (token >= 0 && token < seq_len) {
      const float scale = hidden_states_scale[(hidden / kBlockSize) * seq_len + token];
      q_storage = ue8m0_nearest_power2_storage(scale);
      const float q = ue8m0_storage_to_power2(q_storage);
      const float residual = scale == 0.0f ? 0.0f : fabsf(scale) / q;
      const float sign = scale < 0.0f ? -1.0f : 1.0f;
      const float value =
          fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) * sign * residual;
      adapted_byte = float_to_fp8_e4m3_byte(value);
    }

    expert_b[layout_b(n, hidden, 0)] = adapted_byte;
    expert_sfb[layout_sfb(n, hidden, 0)] = q_storage;
  }
}

__global__ void pack_cutlass92_gemm2_weights_kernel(
    const uint8_t* __restrict__ gemm2_weights,
    const float* __restrict__ gemm2_weights_scale,
    uint8_t* __restrict__ packed_a,
    uint8_t* __restrict__ packed_sfa) {
  const int64_t idx = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(kNumLocalExperts) * kHiddenSize * kIntermediateSize;
  if (idx >= total) {
    return;
  }

  const int32_t intermediate = static_cast<int32_t>(idx % kIntermediateSize);
  const int64_t row_idx = idx / kIntermediateSize;
  const int32_t hidden = static_cast<int32_t>(row_idx % kHiddenSize);
  const int32_t expert = static_cast<int32_t>(row_idx / kHiddenSize);
  const int32_t scale_idx =
      (expert * kHiddenBlocks + (hidden / kBlockSize)) * kIntermediateBlocks + (intermediate / kBlockSize);
  const float scale = gemm2_weights_scale[scale_idx];
  const uint8_t q_storage = ue8m0_nearest_power2_storage(scale);
  const float q = ue8m0_storage_to_power2(q_storage);
  const float residual = scale == 0.0f ? 0.0f : fabsf(scale) / q;
  const float sign = scale < 0.0f ? -1.0f : 1.0f;
  const float adapted = fp8_e4m3_to_float(gemm2_weights[idx]) * sign * residual;

  packed_a[idx] = float_to_fp8_e4m3_byte(adapted);

  auto layout_sfa = Cutlass92BlkScaledConfig::tile_atom_to_shape_SFA(
      cute::make_shape(kHiddenSize, 1, kIntermediateSize, kNumLocalExperts));
  packed_sfa[layout_sfa(hidden, intermediate, expert)] = q_storage;
}

__global__ void init_cutlass92_gemm2_ptrs_kernel(
    const int32_t* __restrict__ starts_by_expert,
    uint8_t* __restrict__ packed_b,
    uint8_t* __restrict__ packed_sfb,
    __nv_bfloat16* __restrict__ expert_output,
    uintptr_t* __restrict__ ptr_b,
    uintptr_t* __restrict__ ptr_sfb,
    uintptr_t* __restrict__ ptr_c,
    uintptr_t* __restrict__ ptr_d,
    int64_t sfb_stride,
    int32_t n_cutlass) {
  const int32_t expert = static_cast<int32_t>(threadIdx.x);
  if (expert >= kNumLocalExperts) {
    return;
  }
  const int64_t start = static_cast<int64_t>(starts_by_expert[expert]);
  ptr_b[expert] =
      reinterpret_cast<uintptr_t>(packed_b + static_cast<int64_t>(expert) * n_cutlass * kIntermediateSize);
  ptr_sfb[expert] = reinterpret_cast<uintptr_t>(packed_sfb + static_cast<int64_t>(expert) * sfb_stride);
  ptr_c[expert] = 0;
  ptr_d[expert] = reinterpret_cast<uintptr_t>(expert_output + start * kHiddenSize);
}

__global__ void fused_swiglu_pack_cutlass92_gemm2_activation_kernel(
    const __nv_bfloat16* __restrict__ gemm1_out,
    const int32_t* __restrict__ compact_row_to_local_expert,
    const int32_t* __restrict__ compact_row_to_expert_row,
    const int32_t* __restrict__ total_local_slots,
    uint8_t* __restrict__ packed_b,
    uint8_t* __restrict__ packed_sfb,
    int64_t sfb_stride,
    int32_t n_cutlass) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t block = static_cast<int32_t>(blockIdx.y);
  const int32_t lane = static_cast<int32_t>(threadIdx.x);
  if (lane >= kBlockSize || block >= kIntermediateBlocks || row >= total_local_slots[0]) {
    return;
  }

  const int32_t expert = compact_row_to_local_expert[row];
  const int32_t n = compact_row_to_expert_row[row];
  if (expert < 0 || expert >= kNumLocalExperts || n < 0 || n >= n_cutlass) {
    return;
  }

  const int32_t intermediate = block * kBlockSize + lane;
  const int64_t gemm1_row = static_cast<int64_t>(row) * kGemm1OutSize;
  const float x1 = __bfloat162float(gemm1_out[gemm1_row + intermediate]);
  const float x2 = __bfloat162float(gemm1_out[gemm1_row + kIntermediateSize + intermediate]);
  const float silu = x2 / (1.0f + expf(-x2));
  const float value = __bfloat162float(__float2bfloat16(silu * x1));

  __shared__ float values[kBlockSize];
  __shared__ float abs_values[kBlockSize];
  __shared__ float q_shared;
  __shared__ uint8_t q_storage_shared;
  values[lane] = value;
  abs_values[lane] = fabsf(value);
  __syncthreads();
  for (int32_t stride = kBlockSize / 2; stride > 0; stride >>= 1) {
    if (lane < stride) {
      abs_values[lane] = fmaxf(abs_values[lane], abs_values[lane + stride]);
    }
    __syncthreads();
  }

  if (lane == 0) {
    const float scale = abs_values[0] > 0.0f ? abs_values[0] / kFp8E4m3MaxFinite : 0.0f;
    q_storage_shared = ue8m0_ceiling_power2_storage(scale);
    q_shared = scale > 0.0f ? ue8m0_storage_to_power2(q_storage_shared) : 1.0f;
  }
  __syncthreads();

  const uint8_t adapted_byte = float_to_fp8_e4m3_byte(values[lane] / q_shared);

  auto stride_b = cutlass::make_cute_packed_stride(
      Cutlass92StrideB{},
      {n_cutlass, static_cast<int32_t>(kIntermediateSize), 1});
  auto layout_b =
      cute::make_layout(cute::make_shape(n_cutlass, static_cast<int32_t>(kIntermediateSize), 1), stride_b);
  auto layout_sfb =
      Cutlass92BlkScaledConfig::tile_atom_to_shape_SFB(cute::make_shape(
          static_cast<int32_t>(kHiddenSize),
          n_cutlass,
          static_cast<int32_t>(kIntermediateSize),
          1));
  uint8_t* expert_b = packed_b + static_cast<int64_t>(expert) * n_cutlass * kIntermediateSize;
  uint8_t* expert_sfb = packed_sfb + static_cast<int64_t>(expert) * sfb_stride;
  expert_b[layout_b(n, intermediate, 0)] = adapted_byte;
  expert_sfb[layout_sfb(n, intermediate, 0)] = q_storage_shared;
}

__global__ void fused_swiglu_pack_cutlass92_gemm2_activation_short_kernel(
    const __nv_bfloat16* __restrict__ gemm1_out,
    const int32_t* __restrict__ compact_row_to_local_expert,
    const int32_t* __restrict__ compact_row_to_expert_row,
    const int32_t* __restrict__ total_local_slots,
    uint8_t* __restrict__ packed_b,
    uint8_t* __restrict__ packed_sfb,
    int64_t sfb_stride,
    int32_t n_cutlass) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t block = static_cast<int32_t>(blockIdx.y);
  const int32_t lane = static_cast<int32_t>(threadIdx.x);
  if (lane >= kShortCutlassGemm2PackThreads || block >= kIntermediateBlocks || row >= total_local_slots[0]) {
    return;
  }

  const int32_t expert = compact_row_to_local_expert[row];
  const int32_t n = compact_row_to_expert_row[row];
  if (expert < 0 || expert >= kNumLocalExperts || n < 0 || n >= n_cutlass) {
    return;
  }

  __shared__ float values[kBlockSize];
  __shared__ float abs_values[kShortCutlassGemm2PackThreads];
  __shared__ float q_shared;
  __shared__ uint8_t q_storage_shared;

  float local_abs_max = 0.0f;
#pragma unroll
  for (int32_t elem = 0; elem < kShortCutlassGemm2PackElemsPerThread; ++elem) {
    const int32_t intermediate = block * kBlockSize + elem * kShortCutlassGemm2PackThreads + lane;
    const int64_t gemm1_row = static_cast<int64_t>(row) * kGemm1OutSize;
    const float x1 = __bfloat162float(gemm1_out[gemm1_row + intermediate]);
    const float x2 = __bfloat162float(gemm1_out[gemm1_row + kIntermediateSize + intermediate]);
    const float silu = x2 / (1.0f + expf(-x2));
    const float value = __bfloat162float(__float2bfloat16(silu * x1));
    values[elem * kShortCutlassGemm2PackThreads + lane] = value;
    local_abs_max = fmaxf(local_abs_max, fabsf(value));
  }
  abs_values[lane] = local_abs_max;
  __syncthreads();

  for (int32_t stride = kShortCutlassGemm2PackThreads / 2; stride > 0; stride >>= 1) {
    if (lane < stride) {
      abs_values[lane] = fmaxf(abs_values[lane], abs_values[lane + stride]);
    }
    __syncthreads();
  }

  if (lane == 0) {
    const float scale = abs_values[0] > 0.0f ? abs_values[0] / kFp8E4m3MaxFinite : 0.0f;
    q_storage_shared = ue8m0_ceiling_power2_storage(scale);
    q_shared = scale > 0.0f ? ue8m0_storage_to_power2(q_storage_shared) : 1.0f;
  }
  __syncthreads();

  auto stride_b = cutlass::make_cute_packed_stride(
      Cutlass92StrideB{},
      {n_cutlass, static_cast<int32_t>(kIntermediateSize), 1});
  auto layout_b =
      cute::make_layout(cute::make_shape(n_cutlass, static_cast<int32_t>(kIntermediateSize), 1), stride_b);
  auto layout_sfb =
      Cutlass92BlkScaledConfig::tile_atom_to_shape_SFB(cute::make_shape(
          static_cast<int32_t>(kHiddenSize),
          n_cutlass,
          static_cast<int32_t>(kIntermediateSize),
          1));
  uint8_t* expert_b = packed_b + static_cast<int64_t>(expert) * n_cutlass * kIntermediateSize;
  uint8_t* expert_sfb = packed_sfb + static_cast<int64_t>(expert) * sfb_stride;

#pragma unroll
  for (int32_t elem = 0; elem < kShortCutlassGemm2PackElemsPerThread; ++elem) {
    const int32_t intermediate = block * kBlockSize + elem * kShortCutlassGemm2PackThreads + lane;
    const uint8_t adapted_byte =
        float_to_fp8_e4m3_byte(values[elem * kShortCutlassGemm2PackThreads + lane] / q_shared);
    expert_b[layout_b(n, intermediate, 0)] = adapted_byte;
    expert_sfb[layout_sfb(n, intermediate, 0)] = q_storage_shared;
  }
}
#endif

__global__ void fused_swiglu_bf16_kernel(
    const __nv_bfloat16* __restrict__ gemm1_out,
    const int32_t* __restrict__ total_local_slots,
    __nv_bfloat16* __restrict__ gated,
    int32_t total_slots) {
  const int64_t idx = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(total_slots) * kIntermediateSize;
  if (idx >= total) {
    return;
  }

  const int32_t row = static_cast<int32_t>(idx / kIntermediateSize);
  const int32_t i = static_cast<int32_t>(idx - static_cast<int64_t>(row) * kIntermediateSize);
  if (row >= total_local_slots[0]) {
    gated[idx] = __float2bfloat16(0.0f);
    return;
  }

  const int64_t gemm1_row = static_cast<int64_t>(row) * kGemm1OutSize;
  const float x1 = __bfloat162float(gemm1_out[gemm1_row + i]);
  const float x2 = __bfloat162float(gemm1_out[gemm1_row + kIntermediateSize + i]);
  const float silu = x2 / (1.0f + expf(-x2));
  gated[idx] = __float2bfloat16(silu * x1);
}

__global__ void reduce_compact_output_bf16_kernel(
    const __nv_bfloat16* __restrict__ compact_output,
    const int32_t* __restrict__ slot_to_compact_row,
    const float* __restrict__ compact_weights,
    const int32_t* __restrict__ total_local_slots,
    __nv_bfloat16* __restrict__ output,
    int32_t seq_len) {
  const int64_t idx = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(seq_len) * kHiddenSize;
  if (idx >= total) {
    return;
  }

  const int32_t token = static_cast<int32_t>(idx / kHiddenSize);
  const int32_t hidden = static_cast<int32_t>(idx - static_cast<int64_t>(token) * kHiddenSize);
  float acc = 0.0f;
  const int32_t live_rows = total_local_slots[0];

#pragma unroll
  for (int32_t k = 0; k < kTopK; ++k) {
    const int32_t slot = token * kTopK + k;
    const int32_t row = slot_to_compact_row[slot];
    if (row >= 0 && row < live_rows) {
      const int64_t compact_idx = static_cast<int64_t>(row) * kHiddenSize + hidden;
      acc = fmaf(__bfloat162float(compact_output[compact_idx]), compact_weights[row], acc);
    }
  }

  output[idx] = __float2bfloat16(acc);
}

__global__ void reduce_compact_output_fp32_kernel(
    const __nv_bfloat16* __restrict__ compact_output,
    const int32_t* __restrict__ slot_to_compact_row,
    const float* __restrict__ compact_weights,
    const int32_t* __restrict__ total_local_slots,
    float* __restrict__ output_fp32,
    int32_t seq_len) {
  const int64_t idx = static_cast<int64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const int64_t total = static_cast<int64_t>(seq_len) * kHiddenSize;
  if (idx >= total) {
    return;
  }

  const int32_t token = static_cast<int32_t>(idx / kHiddenSize);
  const int32_t hidden = static_cast<int32_t>(idx - static_cast<int64_t>(token) * kHiddenSize);
  float acc = 0.0f;
  const int32_t live_rows = total_local_slots[0];

#pragma unroll
  for (int32_t k = 0; k < kTopK; ++k) {
    const int32_t slot = token * kTopK + k;
    const int32_t row = slot_to_compact_row[slot];
    if (row >= 0 && row < live_rows) {
      const int64_t compact_idx = static_cast<int64_t>(row) * kHiddenSize + hidden;
      acc = fmaf(__bfloat162float(compact_output[compact_idx]), compact_weights[row], acc);
    }
  }

  output_fp32[idx] = acc;
}

__global__ void gemm1_swiglu_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const uint8_t* __restrict__ gemm1_weights,
    const float* __restrict__ gemm1_weights_scale,
    const int32_t* __restrict__ topk_idx,
    float* __restrict__ gated,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots) {
  const int32_t slot = static_cast<int32_t>(blockIdx.x);
  const int32_t i = static_cast<int32_t>(blockIdx.y * blockDim.x + threadIdx.x);
  if (slot >= total_slots || i >= kIntermediateSize) {
    return;
  }

  const int32_t token = slot / kTopK;
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (token >= seq_len || local_expert < 0 || local_expert >= kNumLocalExperts) {
    gated[static_cast<int64_t>(slot) * kIntermediateSize + i] = 0.0f;
    return;
  }

  float up = 0.0f;
  float gate = 0.0f;
  const int32_t gate_i = i + kIntermediateSize;
  for (int32_t block = 0; block < kHiddenBlocks; ++block) {
    const float activation_scale = hidden_states_scale[block * seq_len + token];
    const float up_scale =
        gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (i / kBlockSize)) * kHiddenBlocks + block];
    const float gate_scale =
        gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (gate_i / kBlockSize)) * kHiddenBlocks + block];
    const int32_t k_base = block * kBlockSize;
    for (int32_t k = 0; k < kBlockSize; ++k) {
      const int32_t hidden = k_base + k;
      const float activation =
          fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) *
          activation_scale;
      const float up_weight =
          fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + i) *
                                           kHiddenSize + hidden]) *
          up_scale;
      const float gate_weight =
          fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + gate_i) *
                                           kHiddenSize + hidden]) *
          gate_scale;
      up = fmaf(activation, up_weight, up);
      gate = fmaf(activation, gate_weight, gate);
    }
  }

  const float silu_gate = gate / (1.0f + expf(-gate));
  gated[static_cast<int64_t>(slot) * kIntermediateSize + i] = silu_gate * up;
}

__global__ void gemm1_swiglu_compact_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const uint8_t* __restrict__ gemm1_weights,
    const float* __restrict__ gemm1_weights_scale,
    const int32_t* __restrict__ topk_idx,
    const int32_t* __restrict__ compact_slot_ids,
    const int32_t* __restrict__ total_local_slots,
    float* __restrict__ gated,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t i = static_cast<int32_t>(blockIdx.y * blockDim.x + threadIdx.x);
  if (row >= total_slots || row >= total_local_slots[0] || i >= kIntermediateSize) {
    return;
  }

  const int32_t slot = compact_slot_ids[row];
  const int32_t token = slot / kTopK;
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (token >= seq_len || local_expert < 0 || local_expert >= kNumLocalExperts) {
    gated[static_cast<int64_t>(row) * kIntermediateSize + i] = 0.0f;
    return;
  }

  float up = 0.0f;
  float gate = 0.0f;
  const int32_t gate_i = i + kIntermediateSize;
  for (int32_t block = 0; block < kHiddenBlocks; ++block) {
    const float activation_scale = hidden_states_scale[block * seq_len + token];
    const float up_scale =
        gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (i / kBlockSize)) * kHiddenBlocks + block];
    const float gate_scale =
        gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (gate_i / kBlockSize)) * kHiddenBlocks + block];
    const int32_t k_base = block * kBlockSize;
    for (int32_t k = 0; k < kBlockSize; ++k) {
      const int32_t hidden = k_base + k;
      const float activation =
          fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) *
          activation_scale;
      const float up_weight =
          fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + i) *
                                           kHiddenSize + hidden]) *
          up_scale;
      const float gate_weight =
          fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + gate_i) *
                                           kHiddenSize + hidden]) *
          gate_scale;
      up = fmaf(activation, up_weight, up);
      gate = fmaf(activation, gate_weight, gate);
    }
  }

  const float silu_gate = gate / (1.0f + expf(-gate));
  gated[static_cast<int64_t>(row) * kIntermediateSize + i] = silu_gate * up;
}

__global__ void gemm1_compact_reference_bf16_kernel(
    const uint8_t* __restrict__ hidden_states,
    const float* __restrict__ hidden_states_scale,
    const uint8_t* __restrict__ gemm1_weights,
    const float* __restrict__ gemm1_weights_scale,
    const int32_t* __restrict__ topk_idx,
    const int32_t* __restrict__ compact_slot_ids,
    const int32_t* __restrict__ total_local_slots,
    __nv_bfloat16* __restrict__ gemm1_out,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t i = static_cast<int32_t>(blockIdx.y * blockDim.x + threadIdx.x);
  if (row >= total_slots || row >= total_local_slots[0] || i >= kIntermediateSize) {
    return;
  }

  const int32_t slot = compact_slot_ids[row];
  const int32_t token = slot / kTopK;
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  const int64_t out_row = static_cast<int64_t>(row) * kGemm1OutSize;
  if (token >= seq_len || local_expert < 0 || local_expert >= kNumLocalExperts) {
    gemm1_out[out_row + i] = __float2bfloat16(0.0f);
    gemm1_out[out_row + kIntermediateSize + i] = __float2bfloat16(0.0f);
    return;
  }

  float up = 0.0f;
  float gate = 0.0f;
  const int32_t gate_i = i + kIntermediateSize;
  for (int32_t block = 0; block < kHiddenBlocks; ++block) {
    const float activation_scale = hidden_states_scale[block * seq_len + token];
    const float up_scale =
        gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (i / kBlockSize)) * kHiddenBlocks + block];
    const float gate_scale =
        gemm1_weights_scale[(local_expert * kGemm1OutBlocks + (gate_i / kBlockSize)) * kHiddenBlocks + block];
    const int32_t k_base = block * kBlockSize;
    for (int32_t k = 0; k < kBlockSize; ++k) {
      const int32_t hidden = k_base + k;
      const float activation =
          fp8_e4m3_to_float(hidden_states[static_cast<int64_t>(token) * kHiddenSize + hidden]) *
          activation_scale;
      const float up_weight =
          fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + i) *
                                           kHiddenSize + hidden]) *
          up_scale;
      const float gate_weight =
          fp8_e4m3_to_float(gemm1_weights[(static_cast<int64_t>(local_expert) * kGemm1OutSize + gate_i) *
                                           kHiddenSize + hidden]) *
          gate_scale;
      up = fmaf(activation, up_weight, up);
      gate = fmaf(activation, gate_weight, gate);
    }
  }

  gemm1_out[out_row + i] = __float2bfloat16(up);
  gemm1_out[out_row + kIntermediateSize + i] = __float2bfloat16(gate);
}

__global__ void gemm2_accumulate_kernel(
    const uint8_t* __restrict__ gemm2_weights,
    const float* __restrict__ gemm2_weights_scale,
    const int32_t* __restrict__ topk_idx,
    const float* __restrict__ topk_weight,
    const float* __restrict__ gated,
    float* __restrict__ output,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots) {
  const int32_t slot = static_cast<int32_t>(blockIdx.x);
  const int32_t hidden = static_cast<int32_t>(blockIdx.y * blockDim.x + threadIdx.x);
  if (slot >= total_slots || hidden >= kHiddenSize) {
    return;
  }

  const int32_t token = slot / kTopK;
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (token >= seq_len || local_expert < 0 || local_expert >= kNumLocalExperts) {
    return;
  }

  float acc = 0.0f;
  const int32_t hidden_block = hidden / kBlockSize;
  for (int32_t block = 0; block < kIntermediateBlocks; ++block) {
    const float weight_scale =
        gemm2_weights_scale[(local_expert * kHiddenBlocks + hidden_block) * kIntermediateBlocks + block];
    const int32_t i_base = block * kBlockSize;
    for (int32_t offset = 0; offset < kBlockSize; ++offset) {
      const int32_t i = i_base + offset;
      const float weight =
          fp8_e4m3_to_float(gemm2_weights[(static_cast<int64_t>(local_expert) * kHiddenSize + hidden) *
                                           kIntermediateSize + i]) *
          weight_scale;
      acc = fmaf(gated[static_cast<int64_t>(slot) * kIntermediateSize + i], weight, acc);
    }
  }

  atomicAdd(&output[static_cast<int64_t>(token) * kHiddenSize + hidden], topk_weight[slot] * acc);
}

__global__ void gemm2_compact_accumulate_kernel(
    const uint8_t* __restrict__ gemm2_weights,
    const float* __restrict__ gemm2_weights_scale,
    const int32_t* __restrict__ topk_idx,
    const int32_t* __restrict__ compact_slot_ids,
    const float* __restrict__ compact_weights,
    const int32_t* __restrict__ total_local_slots,
    const float* __restrict__ gated,
    float* __restrict__ output,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots) {
  const int32_t row = static_cast<int32_t>(blockIdx.x);
  const int32_t hidden = static_cast<int32_t>(blockIdx.y * blockDim.x + threadIdx.x);
  if (row >= total_slots || row >= total_local_slots[0] || hidden >= kHiddenSize) {
    return;
  }

  const int32_t slot = compact_slot_ids[row];
  const int32_t token = slot / kTopK;
  const int32_t local_expert = topk_idx[slot] - local_expert_offset;
  if (token >= seq_len || local_expert < 0 || local_expert >= kNumLocalExperts) {
    return;
  }

  float acc = 0.0f;
  const int32_t hidden_block = hidden / kBlockSize;
  for (int32_t block = 0; block < kIntermediateBlocks; ++block) {
    const float weight_scale =
        gemm2_weights_scale[(local_expert * kHiddenBlocks + hidden_block) * kIntermediateBlocks + block];
    const int32_t i_base = block * kBlockSize;
    for (int32_t offset = 0; offset < kBlockSize; ++offset) {
      const int32_t i = i_base + offset;
      const float weight =
          fp8_e4m3_to_float(gemm2_weights[(static_cast<int64_t>(local_expert) * kHiddenSize + hidden) *
                                           kIntermediateSize + i]) *
          weight_scale;
      acc = fmaf(gated[static_cast<int64_t>(row) * kIntermediateSize + i], weight, acc);
    }
  }

  atomicAdd(&output[static_cast<int64_t>(token) * kHiddenSize + hidden], compact_weights[row] * acc);
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

__global__ void compare_bf16_to_fp32_kernel(
    const __nv_bfloat16* __restrict__ candidate,
    const float* __restrict__ reference,
    int32_t* __restrict__ status,
    int32_t count) {
  const int32_t idx = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (idx >= count) {
    return;
  }

  const float candidate_value = __bfloat162float(candidate[idx]);
  const float reference_value = reference[idx];
  const float diff = fabsf(candidate_value - reference_value);
  const float tolerance = 8.0f + 0.75f * fabsf(reference_value);
  if (!isfinite(candidate_value) || !isfinite(reference_value) || diff > tolerance) {
    atomicAdd(status, 1);
  }
}

__global__ void compare_bf16_pair_kernel(
    const __nv_bfloat16* __restrict__ candidate,
    const __nv_bfloat16* __restrict__ reference,
    int32_t* __restrict__ status,
    int32_t count) {
  const int32_t idx = static_cast<int32_t>(blockIdx.x * blockDim.x + threadIdx.x);
  if (idx >= count) {
    return;
  }

  const float candidate_value = __bfloat162float(candidate[idx]);
  const float reference_value = __bfloat162float(reference[idx]);
  const float diff = fabsf(candidate_value - reference_value);
  const float tolerance = 8.0f + 0.75f * fabsf(reference_value);
  if (!isfinite(candidate_value) || !isfinite(reference_value) || diff > tolerance) {
    atomicAdd(status, 1);
  }
}

void maybe_validate_compact_metadata(
    const int32_t* topk_idx,
    const int32_t* compact_slot_ids,
    const int32_t* slot_to_compact_row,
    const int32_t* total_local_slots,
    int32_t local_expert_offset,
    int32_t total_slots,
    cudaStream_t stream) {
  if (!env_flag_is_one(kDebugCompactMetadataEnv)) {
    return;
  }

  DeviceBuffer status_buffer(sizeof(int32_t), stream);
  check_cuda(cudaMemsetAsync(status_buffer.raw(), 0, sizeof(int32_t), stream), "cudaMemsetAsync compact debug status");
  constexpr int32_t kThreads = 256;
  const int32_t blocks = (total_slots + kThreads - 1) / kThreads;
  validate_compact_metadata_kernel<<<blocks, kThreads, 0, stream>>>(
      topk_idx,
      compact_slot_ids,
      slot_to_compact_row,
      total_local_slots,
      status_buffer.data<int32_t>(),
      local_expert_offset,
      total_slots);
  check_launch("validate_compact_metadata_kernel");

  int32_t status_host = 0;
  check_cuda(
      cudaMemcpyAsync(&status_host, status_buffer.data<int32_t>(), sizeof(int32_t), cudaMemcpyDeviceToHost, stream),
      "cudaMemcpyAsync compact debug status");
  check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize compact debug status");
  if (status_host != 0) {
    TVM_FFI_THROW(RuntimeError) << "compact metadata debug check failed with status " << status_host;
  }
}

void launch_route_topk(
    bool use_short_route,
    const float* routing_logits,
    const __nv_bfloat16* routing_bias,
    int32_t* topk_idx,
    float* topk_weight,
    int32_t local_expert_offset,
    float routed_scaling_factor,
    int32_t seq_len,
    cudaStream_t stream) {
  if (use_short_route) {
    route_topk_short_kernel<<<seq_len, 32, 0, stream>>>(
        routing_logits,
        routing_bias,
        topk_idx,
        topk_weight,
        routed_scaling_factor,
        seq_len);
    check_launch("route_topk_short_kernel");
    return;
  }

  route_topk_kernel<<<seq_len, kNumExpertsGlobal, 0, stream>>>(
      routing_logits,
      routing_bias,
      topk_idx,
      topk_weight,
      local_expert_offset,
      routed_scaling_factor,
      seq_len);
  check_launch("route_topk_kernel");
}

void launch_short_compact_metadata(
    const int32_t* topk_idx,
    const float* topk_weight,
    int32_t* counts_by_expert,
    int32_t* starts_by_expert,
    int32_t* offsets_by_expert,
    int32_t* compact_slot_ids,
    int32_t* slot_to_compact_row,
    float* compact_weights,
    int32_t* total_local_slots,
    int32_t local_expert_offset,
    int32_t total_slots,
    cudaStream_t stream) {
  build_short_compact_metadata_kernel<<<1, 1, 0, stream>>>(
      topk_idx,
      topk_weight,
      counts_by_expert,
      starts_by_expert,
      offsets_by_expert,
      compact_slot_ids,
      slot_to_compact_row,
      compact_weights,
      total_local_slots,
      local_expert_offset,
      total_slots);
  check_launch("build_short_compact_metadata_kernel");
  maybe_validate_compact_metadata(
      topk_idx,
      compact_slot_ids,
      slot_to_compact_row,
      total_local_slots,
      local_expert_offset,
      total_slots,
      stream);
}

void launch_short_cutlass92_metadata(
    const int32_t* topk_idx,
    const float* topk_weight,
    int32_t* counts_by_expert,
    int32_t* starts_by_expert,
    int32_t* offsets_by_expert,
    int32_t* compact_slot_ids,
    int32_t* slot_to_compact_row,
    float* compact_weights,
    int32_t* total_local_slots,
    int32_t* compact_row_to_local_expert,
    int32_t* compact_row_to_expert_row,
    int32_t local_expert_offset,
    int32_t total_slots,
    cudaStream_t stream) {
  build_short_cutlass92_metadata_kernel<<<1, 1, 0, stream>>>(
      topk_idx,
      topk_weight,
      counts_by_expert,
      starts_by_expert,
      offsets_by_expert,
      compact_slot_ids,
      slot_to_compact_row,
      compact_weights,
      total_local_slots,
      compact_row_to_local_expert,
      compact_row_to_expert_row,
      local_expert_offset,
      total_slots);
  check_launch("build_short_cutlass92_metadata_kernel");
  maybe_validate_compact_metadata(
      topk_idx,
      compact_slot_ids,
      slot_to_compact_row,
      total_local_slots,
      local_expert_offset,
      total_slots,
      stream);
}

bool validate_cutlass92_metadata_contract(
    const int32_t* compact_slot_ids,
    const int32_t* row_owner_local_expert,
    const int32_t* row_owner_expert_row,
    const int32_t* counts_by_expert,
    const int32_t* starts_by_expert,
    const int32_t* offsets_by_expert,
    const int32_t* total_local_slots,
    int32_t total_slots,
    cudaStream_t stream) {
  std::vector<int32_t> compact_slot_ids_host(total_slots);
  std::vector<int32_t> row_owner_local_expert_host(total_slots);
  std::vector<int32_t> row_owner_expert_row_host(total_slots);
  std::vector<int32_t> counts_host(kNumLocalExperts);
  std::vector<int32_t> starts_host(kNumLocalExperts);
  std::vector<int32_t> offsets_host(kNumLocalExperts);
  int32_t total_local_slots_host = 0;
  check_cuda(
      cudaMemcpyAsync(
          compact_slot_ids_host.data(),
          compact_slot_ids,
          checked_bytes(total_slots, sizeof(int32_t), "contract compact_slot_ids"),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract compact_slot_ids");
  check_cuda(
      cudaMemcpyAsync(
          row_owner_local_expert_host.data(),
          row_owner_local_expert,
          checked_bytes(total_slots, sizeof(int32_t), "contract row_owner_local_expert"),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract row_owner_local_expert");
  check_cuda(
      cudaMemcpyAsync(
          row_owner_expert_row_host.data(),
          row_owner_expert_row,
          checked_bytes(total_slots, sizeof(int32_t), "contract row_owner_expert_row"),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract row_owner_expert_row");
  check_cuda(
      cudaMemcpyAsync(
          counts_host.data(),
          counts_by_expert,
          checked_bytes(kNumLocalExperts, sizeof(int32_t), "contract counts_by_expert"),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract counts_by_expert");
  check_cuda(
      cudaMemcpyAsync(
          starts_host.data(),
          starts_by_expert,
          checked_bytes(kNumLocalExperts, sizeof(int32_t), "contract starts_by_expert"),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract starts_by_expert");
  check_cuda(
      cudaMemcpyAsync(
          offsets_host.data(),
          offsets_by_expert,
          checked_bytes(kNumLocalExperts, sizeof(int32_t), "contract offsets_by_expert"),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract offsets_by_expert");
  check_cuda(
      cudaMemcpyAsync(
          &total_local_slots_host,
          total_local_slots,
          sizeof(int32_t),
          cudaMemcpyDeviceToHost,
          stream),
      "cudaMemcpyAsync contract total_local_slots");
  check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize contract validation");

  if (total_local_slots_host < 0 || total_local_slots_host > total_slots) {
    return false;
  }
  int32_t prefix = 0;
  std::vector<int32_t> seen(total_local_slots_host > 0 ? total_local_slots_host : 0, 0);
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    if (counts_host[expert] < 0 || starts_host[expert] != prefix ||
        offsets_host[expert] != starts_host[expert] + counts_host[expert]) {
      return false;
    }
    prefix += counts_host[expert];
  }
  if (prefix != total_local_slots_host) {
    return false;
  }
  for (int32_t row = 0; row < total_local_slots_host; ++row) {
    const int32_t expert = row_owner_local_expert_host[row];
    const int32_t expert_row = row_owner_expert_row_host[row];
    if (expert < 0 || expert >= kNumLocalExperts) {
      return false;
    }
    if (expert_row < 0 || expert_row >= counts_host[expert]) {
      return false;
    }
    if (starts_host[expert] + expert_row != row) {
      return false;
    }
    if (compact_slot_ids_host[row] < 0 || compact_slot_ids_host[row] >= total_slots) {
      return false;
    }
    if (row < static_cast<int32_t>(seen.size())) {
      seen[row] += 1;
    }
  }
  for (int32_t row = 0; row < static_cast<int32_t>(seen.size()); ++row) {
    if (seen[row] != 1) {
      return false;
    }
  }
  return true;
}

float matched_ratio_for_bf16_pair_compare(
    const __nv_bfloat16* candidate,
    const __nv_bfloat16* reference,
    int32_t count,
    cudaStream_t stream,
    const char* status_name) {
  DeviceBuffer status_buffer(sizeof(int32_t), stream);
  check_cuda(cudaMemsetAsync(status_buffer.raw(), 0, sizeof(int32_t), stream), status_name);
  constexpr int32_t kThreads = 128;
  const int32_t blocks = (count + kThreads - 1) / kThreads;
  compare_bf16_pair_kernel<<<blocks, kThreads, 0, stream>>>(
      candidate,
      reference,
      status_buffer.data<int32_t>(),
      count);
  check_launch("compare_bf16_pair_kernel");
  int32_t status_host = 0;
  check_cuda(
      cudaMemcpyAsync(&status_host, status_buffer.data<int32_t>(), sizeof(int32_t), cudaMemcpyDeviceToHost, stream),
      "cudaMemcpyAsync bf16 pair compare status");
  check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize bf16 pair compare status");
  return count > 0 ? 1.0f - static_cast<float>(status_host) / static_cast<float>(count) : 1.0f;
}

float cutlass92_compare_gemm1_output_matched_ratio(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const int32_t* topk_idx,
    const int32_t* compact_slot_ids,
    const int32_t* total_local_slots,
    const __nv_bfloat16* cutlass_gemm1_out,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots,
    cudaStream_t stream) {
  DeviceBuffer reference_output(
      checked_bytes(static_cast<int64_t>(total_slots) * kGemm1OutSize, sizeof(__nv_bfloat16), "gemm1_reference_output"),
      stream);
  constexpr int32_t kThreads = 128;
  const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
  gemm1_compact_reference_bf16_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
      hidden_states,
      hidden_states_scale,
      gemm1_weights,
      gemm1_weights_scale,
      topk_idx,
      compact_slot_ids,
      total_local_slots,
      reference_output.data<__nv_bfloat16>(),
      local_expert_offset,
      seq_len,
      total_slots);
  check_launch("gemm1_compact_reference_bf16_kernel");
  return matched_ratio_for_bf16_pair_compare(
      cutlass_gemm1_out,
      reference_output.data<__nv_bfloat16>(),
      total_slots * kGemm1OutSize,
      stream,
      "cudaMemsetAsync gemm1 compare status");
}

void cutlass92_prepare_final_output_reference(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const int32_t* topk_idx,
    const int32_t* compact_slot_ids,
    const float* compact_weights,
    const int32_t* total_local_slots,
    float* gated,
    float* output_fp32,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots,
    int32_t total_output,
    const PrepareReferenceComponentConfig* component_config,
    cudaStream_t stream);

float cutlass92_compare_final_output_tail_matched_ratio(
    float* output_fp32,
    const __nv_bfloat16* optimized_output,
    int32_t total_output,
    cudaStream_t stream);

float cutlass92_compare_final_output_matched_ratio(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const int32_t* topk_idx,
    const int32_t* compact_slot_ids,
    const float* compact_weights,
    const int32_t* total_local_slots,
    float* gated,
    float* output_fp32,
    const __nv_bfloat16* optimized_output,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots,
    int32_t total_output,
    cudaStream_t stream) {
  cutlass92_prepare_final_output_reference(
      hidden_states,
      hidden_states_scale,
      gemm1_weights,
      gemm1_weights_scale,
      gemm2_weights,
      gemm2_weights_scale,
      topk_idx,
      compact_slot_ids,
      compact_weights,
      total_local_slots,
      gated,
      output_fp32,
      local_expert_offset,
      seq_len,
      total_slots,
      total_output,
      nullptr,
      stream);
  return cutlass92_compare_final_output_tail_matched_ratio(output_fp32, optimized_output, total_output, stream);
}

void cutlass92_prepare_final_output_reference(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const int32_t* topk_idx,
    const int32_t* compact_slot_ids,
    const float* compact_weights,
    const int32_t* total_local_slots,
    float* gated,
    float* output_fp32,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots,
    int32_t total_output,
    const PrepareReferenceComponentConfig* component_config,
    cudaStream_t stream) {
  constexpr int32_t kThreads = 128;
  const bool zero_output = component_config == nullptr || component_config->zero_output_fp32;
  const bool run_gemm1 = component_config == nullptr || component_config->fallback_gemm1_prepare;
  const bool run_gemm2 = component_config == nullptr || component_config->fallback_gemm2_accumulation;
  if (zero_output) {
    check_cuda(
        cudaMemsetAsync(
            output_fp32,
            0,
            checked_bytes(static_cast<int64_t>(total_output), sizeof(float), "stage compare output_fp32"),
            stream),
        "cudaMemsetAsync stage compare output_fp32");
  }
  if (run_gemm1) {
    const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
    gemm1_swiglu_compact_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
        hidden_states,
        hidden_states_scale,
        gemm1_weights,
        gemm1_weights_scale,
        topk_idx,
        compact_slot_ids,
        total_local_slots,
        gated,
        local_expert_offset,
        seq_len,
        total_slots);
    check_launch("stage compare gemm1_swiglu_compact_kernel");
  }
  if (run_gemm2) {
    const dim3 gemm2_grid(total_slots, (kHiddenSize + kThreads - 1) / kThreads);
    gemm2_compact_accumulate_kernel<<<gemm2_grid, kThreads, 0, stream>>>(
        gemm2_weights,
        gemm2_weights_scale,
        topk_idx,
        compact_slot_ids,
        compact_weights,
        total_local_slots,
        gated,
        output_fp32,
        local_expert_offset,
        seq_len,
        total_slots);
    check_launch("stage compare gemm2_compact_accumulate_kernel");
  }
}

float cutlass92_compare_final_output_tail_matched_ratio(
    float* output_fp32,
    const __nv_bfloat16* optimized_output,
    int32_t total_output,
    cudaStream_t stream) {
  constexpr int32_t kThreads = 128;
  DeviceBuffer status_buffer(sizeof(int32_t), stream);
  check_cuda(cudaMemsetAsync(status_buffer.raw(), 0, sizeof(int32_t), stream), "cudaMemsetAsync stage compare status");
  const int32_t blocks = (total_output + kThreads - 1) / kThreads;
  compare_bf16_to_fp32_kernel<<<blocks, kThreads, 0, stream>>>(
      optimized_output,
      output_fp32,
      status_buffer.data<int32_t>(),
      total_output);
  check_launch("stage compare compare_bf16_to_fp32_kernel");

  int32_t status_host = 0;
  check_cuda(
      cudaMemcpyAsync(&status_host, status_buffer.data<int32_t>(), sizeof(int32_t), cudaMemcpyDeviceToHost, stream),
      "cudaMemcpyAsync stage compare status");
  check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize stage compare status");
  return total_output > 0 ? 1.0f - static_cast<float>(status_host) / static_cast<float>(total_output) : 1.0f;
}

void maybe_compare_cutlass92_with_compact_fallback(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const int32_t* topk_idx,
    const int32_t* compact_slot_ids,
    const float* compact_weights,
    const int32_t* total_local_slots,
    float* gated,
    float* output_fp32,
    const __nv_bfloat16* optimized_output,
    int32_t local_expert_offset,
    int32_t seq_len,
    int32_t total_slots,
    int32_t total_output,
    cudaStream_t stream) {
  if (!env_flag_is_one(kDebugCompareCutlass92Env) || seq_len > kDebugCompareCutlass92MaxSeqLen) {
    return;
  }

  constexpr int32_t kThreads = 128;
  check_cuda(
      cudaMemsetAsync(
          output_fp32,
          0,
          checked_bytes(static_cast<int64_t>(total_output), sizeof(float), "debug_compare_output_fp32"),
          stream),
      "cudaMemsetAsync debug compare output_fp32");
  const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
  gemm1_swiglu_compact_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
      hidden_states,
      hidden_states_scale,
      gemm1_weights,
      gemm1_weights_scale,
      topk_idx,
      compact_slot_ids,
      total_local_slots,
      gated,
      local_expert_offset,
      seq_len,
      total_slots);
  check_launch("debug gemm1_swiglu_compact_kernel");

  const dim3 gemm2_grid(total_slots, (kHiddenSize + kThreads - 1) / kThreads);
  gemm2_compact_accumulate_kernel<<<gemm2_grid, kThreads, 0, stream>>>(
      gemm2_weights,
      gemm2_weights_scale,
      topk_idx,
      compact_slot_ids,
      compact_weights,
      total_local_slots,
      gated,
      output_fp32,
      local_expert_offset,
      seq_len,
      total_slots);
  check_launch("debug gemm2_compact_accumulate_kernel");

  DeviceBuffer status_buffer(sizeof(int32_t), stream);
  check_cuda(cudaMemsetAsync(status_buffer.raw(), 0, sizeof(int32_t), stream), "cudaMemsetAsync compare debug status");
  const int32_t blocks = (total_output + kThreads - 1) / kThreads;
  compare_bf16_to_fp32_kernel<<<blocks, kThreads, 0, stream>>>(
      optimized_output,
      output_fp32,
      status_buffer.data<int32_t>(),
      total_output);
  check_launch("compare_bf16_to_fp32_kernel");

  int32_t status_host = 0;
  check_cuda(
      cudaMemcpyAsync(&status_host, status_buffer.data<int32_t>(), sizeof(int32_t), cudaMemcpyDeviceToHost, stream),
      "cudaMemcpyAsync compare debug status");
  check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize compare debug status");
  const float matched_ratio =
      total_output > 0 ? 1.0f - static_cast<float>(status_host) / static_cast<float>(total_output) : 1.0f;
  if (matched_ratio < kDebugCompareMinMatchedRatio) {
    TVM_FFI_THROW(RuntimeError)
        << "CUTLASS 92 debug compare matched ratio " << matched_ratio
        << " is below threshold " << kDebugCompareMinMatchedRatio;
  }
}

#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
struct DenseWeightCacheKey {
  uintptr_t weight_data = 0;
  uintptr_t scale_data = 0;
  int32_t device_index = 0;
  int32_t kind = 0;

  bool operator==(const DenseWeightCacheKey& other) const {
    return weight_data == other.weight_data && scale_data == other.scale_data
        && device_index == other.device_index && kind == other.kind;
  }
};

struct DenseWeightCacheKeyHash {
  std::size_t operator()(const DenseWeightCacheKey& key) const {
    std::size_t seed = std::hash<uintptr_t>{}(key.weight_data);
    seed ^= std::hash<uintptr_t>{}(key.scale_data) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    seed ^= std::hash<int32_t>{}(key.device_index) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    seed ^= std::hash<int32_t>{}(key.kind) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    return seed;
  }
};

struct CachedDeviceAllocation {
  explicit CachedDeviceAllocation(size_t bytes) : bytes(bytes) {
    check_cuda(cudaMalloc(&ptr, bytes), "cudaMalloc cached CUTLASS allocation");
  }

  ~CachedDeviceAllocation() {
    if (ptr != nullptr) {
      cudaFree(ptr);
    }
  }

  CachedDeviceAllocation(const CachedDeviceAllocation&) = delete;
  CachedDeviceAllocation& operator=(const CachedDeviceAllocation&) = delete;

  uint8_t* ptr = nullptr;
  size_t bytes = 0;
};

struct Cutlass92WeightPack {
  std::shared_ptr<CachedDeviceAllocation> packed_a;
  std::shared_ptr<CachedDeviceAllocation> packed_sfa;
};

struct Cutlass92GroupedCounts {
  int32_t max_count = 0;
  int32_t total_live_slots = 0;
  int32_t n_cutlass = 0;
};

enum class Cutlass92ScheduleKind : int32_t {
  k1Sm = 1,
  k2Sm = 2,
};

struct Cutlass92Gemm1Result {
  bool ok = false;
  std::shared_ptr<CachedDeviceAllocation> output;
  Cutlass92GroupedCounts counts;
  Cutlass92ScheduleKind schedule = Cutlass92ScheduleKind::k1Sm;
  bool used_retained_weight_state = false;
  bool used_retained_launch_state = false;
};

struct Cutlass92Gemm2Result {
  bool ok = false;
  std::shared_ptr<CachedDeviceAllocation> output;
  bool used_retained_weight_state = false;
  bool used_retained_launch_state = false;
};

struct Cutlass92InvocationTrace {
  uint64_t invocation_id = 0;
  bool runtime_enabled = false;
  bool gemm1_ok = false;
  bool gemm2_ok = false;
  bool fp32_finalization_active = false;
  bool post_gemm2_materialization_active = false;
  bool reduction_consumed_materialized_gemm2 = false;
  bool gemm2_ref_component_bisection_active = false;
  bool gemm2_ref_prepare_reference_active = false;
  bool gemm2_ref_compare_tail_active = false;
  bool prepare_reference_component_bisection_active = false;
  bool prepare_reference_zero_output_active = false;
  bool prepare_reference_gemm1_active = false;
  bool prepare_reference_gemm2_accumulation_active = false;
  bool stateless_diagnostic = false;
  bool full_temp_init_active = false;
  bool stage_validation_active = false;
  bool perturbation_bisection_active = false;
  bool private_stream_active = false;
  bool device_fence_active = false;
  bool retained_weight_state = false;
  bool retained_launch_state = false;
  bool init_cutlass_launch_family = false;
  bool perturb_metadata_hostcopy_sync = false;
  bool perturb_gemm1_reference_compare = false;
  bool perturb_gemm2_reference_compare = false;
  bool perturb_sync_after_metadata = false;
  bool perturb_sync_after_gemm1 = false;
  bool perturb_sync_after_gemm2 = false;
  bool metadata_stage_ok = false;
  bool gemm1_stage_ok = false;
  bool gemm2_stage_ok = false;
  const char* first_failed_stage = "not_run";
  uintptr_t caller_stream = 0;
  uintptr_t execution_stream = 0;
  Cutlass92ScheduleKind schedule = Cutlass92ScheduleKind::k1Sm;
  int32_t n_cutlass = 0;
  int32_t total_live_slots = 0;
};

struct Cutlass92LaunchCacheKey {
  int32_t device_index = 0;
  uintptr_t stream = 0;

  bool operator==(const Cutlass92LaunchCacheKey& other) const {
    return device_index == other.device_index && stream == other.stream;
  }
};

struct Cutlass92LaunchCacheKeyHash {
  std::size_t operator()(const Cutlass92LaunchCacheKey& key) const {
    std::size_t seed = std::hash<int32_t>{}(key.device_index);
    seed ^= std::hash<uintptr_t>{}(key.stream) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    return seed;
  }
};

struct Cutlass92Gemm1LaunchBuffers {
  std::shared_ptr<CachedDeviceAllocation> packed_b;
  std::shared_ptr<CachedDeviceAllocation> packed_sfb;
  std::shared_ptr<CachedDeviceAllocation> output;
  std::shared_ptr<CachedDeviceAllocation> ptr_b;
  std::shared_ptr<CachedDeviceAllocation> ptr_sfb;
  std::shared_ptr<CachedDeviceAllocation> ptr_c;
  std::shared_ptr<CachedDeviceAllocation> ptr_d;
  std::shared_ptr<CachedDeviceAllocation> workspace;
};

struct Cutlass92Gemm2LaunchBuffers {
  std::shared_ptr<CachedDeviceAllocation> packed_b;
  std::shared_ptr<CachedDeviceAllocation> packed_sfb;
  std::shared_ptr<CachedDeviceAllocation> output;
  std::shared_ptr<CachedDeviceAllocation> ptr_b;
  std::shared_ptr<CachedDeviceAllocation> ptr_sfb;
  std::shared_ptr<CachedDeviceAllocation> ptr_c;
  std::shared_ptr<CachedDeviceAllocation> ptr_d;
  std::shared_ptr<CachedDeviceAllocation> workspace;
};

const char* cutlass92_schedule_name(Cutlass92ScheduleKind schedule) {
  return schedule == Cutlass92ScheduleKind::k2Sm ? "2sm" : "1sm";
}

void maybe_log_cutlass92_trace(int32_t seq_len, const Cutlass92InvocationTrace& trace) {
  if (!trace.stateless_diagnostic && !trace.full_temp_init_active && !trace.stage_validation_active &&
      !trace.perturbation_bisection_active &&
      !trace.post_gemm2_materialization_active &&
      !trace.gemm2_ref_component_bisection_active &&
      !trace.prepare_reference_component_bisection_active &&
      !trace.private_stream_active &&
      !cutlass92_path_trace_enabled()) {
    return;
  }
  std::fprintf(
      stderr,
      "[cutlass92] invocation=%llu seq_len=%d runtime=%d gemm1=%d gemm2=%d stateless=%d full_temp_init=%d stage_validation=%d perturbation_bisection=%d fp32_finalization=%d post_gemm2_materialization=%d materialized_reduce_input=%d gemm2_ref_components=%d gemm2_ref_prepare=%d gemm2_ref_tail=%d prepare_ref_components=%d prepare_zero=%d prepare_gemm1=%d prepare_gemm2=%d init_cutlass_launch=%d meta_hostcopy=%d gemm1_ref=%d gemm2_ref=%d sync_meta=%d sync_gemm1=%d sync_gemm2=%d metadata_ok=%d gemm1_ok_stage=%d gemm2_ok_stage=%d first_failed=%s private_stream=%d device_fence=%d caller_stream=0x%llx execution_stream=0x%llx retained_weights=%d retained_launch=%d n=%d live=%d schedule=%s\n",
      static_cast<unsigned long long>(trace.invocation_id),
      seq_len,
      trace.runtime_enabled ? 1 : 0,
      trace.gemm1_ok ? 1 : 0,
      trace.gemm2_ok ? 1 : 0,
      trace.stateless_diagnostic ? 1 : 0,
      trace.full_temp_init_active ? 1 : 0,
      trace.stage_validation_active ? 1 : 0,
      trace.perturbation_bisection_active ? 1 : 0,
      trace.fp32_finalization_active ? 1 : 0,
      trace.post_gemm2_materialization_active ? 1 : 0,
      trace.reduction_consumed_materialized_gemm2 ? 1 : 0,
      trace.gemm2_ref_component_bisection_active ? 1 : 0,
      trace.gemm2_ref_prepare_reference_active ? 1 : 0,
      trace.gemm2_ref_compare_tail_active ? 1 : 0,
      trace.prepare_reference_component_bisection_active ? 1 : 0,
      trace.prepare_reference_zero_output_active ? 1 : 0,
      trace.prepare_reference_gemm1_active ? 1 : 0,
      trace.prepare_reference_gemm2_accumulation_active ? 1 : 0,
      trace.init_cutlass_launch_family ? 1 : 0,
      trace.perturb_metadata_hostcopy_sync ? 1 : 0,
      trace.perturb_gemm1_reference_compare ? 1 : 0,
      trace.perturb_gemm2_reference_compare ? 1 : 0,
      trace.perturb_sync_after_metadata ? 1 : 0,
      trace.perturb_sync_after_gemm1 ? 1 : 0,
      trace.perturb_sync_after_gemm2 ? 1 : 0,
      trace.metadata_stage_ok ? 1 : 0,
      trace.gemm1_stage_ok ? 1 : 0,
      trace.gemm2_stage_ok ? 1 : 0,
      trace.first_failed_stage,
      trace.private_stream_active ? 1 : 0,
      trace.device_fence_active ? 1 : 0,
      static_cast<unsigned long long>(trace.caller_stream),
      static_cast<unsigned long long>(trace.execution_stream),
      trace.retained_weight_state ? 1 : 0,
      trace.retained_launch_state ? 1 : 0,
      trace.n_cutlass,
      trace.total_live_slots,
      cutlass92_schedule_name(trace.schedule));
  std::fflush(stderr);
}

std::mutex g_cutlass92_gemm1_weight_cache_mutex;
std::unordered_map<DenseWeightCacheKey, Cutlass92WeightPack, DenseWeightCacheKeyHash>
    g_cutlass92_gemm1_weight_cache;
std::mutex g_cutlass92_gemm2_weight_cache_mutex;
std::unordered_map<DenseWeightCacheKey, Cutlass92WeightPack, DenseWeightCacheKeyHash>
    g_cutlass92_gemm2_weight_cache;
std::mutex g_cutlass92_gemm1_launch_cache_mutex;
std::unordered_map<Cutlass92LaunchCacheKey, std::shared_ptr<Cutlass92Gemm1LaunchBuffers>, Cutlass92LaunchCacheKeyHash>
    g_cutlass92_gemm1_launch_cache;
std::mutex g_cutlass92_gemm2_launch_cache_mutex;
std::unordered_map<Cutlass92LaunchCacheKey, std::shared_ptr<Cutlass92Gemm2LaunchBuffers>, Cutlass92LaunchCacheKeyHash>
    g_cutlass92_gemm2_launch_cache;

void ensure_cached_allocation(
    std::shared_ptr<CachedDeviceAllocation>* allocation,
    size_t bytes) {
  if (bytes == 0) {
    allocation->reset();
    return;
  }
  if (!*allocation || (*allocation)->bytes < bytes) {
    *allocation = std::make_shared<CachedDeviceAllocation>(bytes);
  }
}

template <typename Buffers>
void ensure_cutlass92_ptr_arrays(Buffers* buffers) {
  ensure_cached_allocation(&buffers->ptr_b, checked_bytes(kNumLocalExperts, sizeof(uintptr_t), "cutlass92_ptr_b"));
  ensure_cached_allocation(&buffers->ptr_sfb, checked_bytes(kNumLocalExperts, sizeof(uintptr_t), "cutlass92_ptr_sfb"));
  ensure_cached_allocation(&buffers->ptr_c, checked_bytes(kNumLocalExperts, sizeof(uintptr_t), "cutlass92_ptr_c"));
  ensure_cached_allocation(&buffers->ptr_d, checked_bytes(kNumLocalExperts, sizeof(uintptr_t), "cutlass92_ptr_d"));
}

std::shared_ptr<Cutlass92Gemm1LaunchBuffers> cached_cutlass92_gemm1_launch_buffers(
    int32_t device_index,
    cudaStream_t stream) {
  const Cutlass92LaunchCacheKey key{device_index, reinterpret_cast<uintptr_t>(stream)};
  std::lock_guard<std::mutex> lock(g_cutlass92_gemm1_launch_cache_mutex);
  const auto it = g_cutlass92_gemm1_launch_cache.find(key);
  if (it != g_cutlass92_gemm1_launch_cache.end()) {
    return it->second;
  }
  auto buffers = std::make_shared<Cutlass92Gemm1LaunchBuffers>();
  g_cutlass92_gemm1_launch_cache.emplace(key, buffers);
  return buffers;
}

std::shared_ptr<Cutlass92Gemm2LaunchBuffers> cached_cutlass92_gemm2_launch_buffers(
    int32_t device_index,
    cudaStream_t stream) {
  const Cutlass92LaunchCacheKey key{device_index, reinterpret_cast<uintptr_t>(stream)};
  std::lock_guard<std::mutex> lock(g_cutlass92_gemm2_launch_cache_mutex);
  const auto it = g_cutlass92_gemm2_launch_cache.find(key);
  if (it != g_cutlass92_gemm2_launch_cache.end()) {
    return it->second;
  }
  auto buffers = std::make_shared<Cutlass92Gemm2LaunchBuffers>();
  g_cutlass92_gemm2_launch_cache.emplace(key, buffers);
  return buffers;
}

bool cutlass92_runtime_enabled(int64_t seq_len) {
  return seq_len >= kCutlass92MediumSeqLenGate && !env_flag_is_one(kDisableCutlass92Env);
}

bool cutlass92_gemm2_runtime_enabled(int64_t seq_len) {
  return cutlass92_runtime_enabled(seq_len) && !env_flag_is_one(kDisableCutlass92Gemm2Env);
}

bool device_supports_cutlass92(int device_index) {
  cudaDeviceProp props;
  check_cuda(cudaGetDeviceProperties(&props, device_index), "cudaGetDeviceProperties");
  return props.major == 10 && (props.minor == 0 || props.minor == 1 || props.minor == 3);
}

bool cutlass92_launch_with_pdl() {
  return env_flag_is_one(kEnableCutlass92PdlEnv);
}

dim3 cutlass92_cluster_shape(Cutlass92ScheduleKind schedule) {
  return schedule == Cutlass92ScheduleKind::k2Sm ? dim3(2, 1, 1) : dim3(1, 1, 1);
}

Cutlass92ScheduleKind select_cutlass92_schedule(
    const Cutlass92GroupedCounts& grouped_counts,
    int32_t seq_len) {
  constexpr int32_t kCutlass922SmMinGroupedN = 16;
  constexpr int64_t kCutlass922SmMinGroupedWork =
      static_cast<int64_t>(kCutlass92MediumSeqLenGate) * kTopK * kCutlass922SmMinGroupedN;
  const bool force_1sm = env_flag_is_one(kForceCutlass921SmEnv);
  const bool force_2sm = env_flag_is_one(kForceCutlass922SmEnv);
  if (force_1sm && !force_2sm) {
    return Cutlass92ScheduleKind::k1Sm;
  }
  if (force_2sm && !force_1sm) {
    return Cutlass92ScheduleKind::k2Sm;
  }
  if (seq_len >= kCutlass922SmSeqLenGate) {
    return Cutlass92ScheduleKind::k2Sm;
  }
  const int64_t grouped_work =
      static_cast<int64_t>(grouped_counts.total_live_slots) * grouped_counts.n_cutlass;
  if (grouped_counts.n_cutlass >= kCutlass922SmMinGroupedN &&
      grouped_work >= kCutlass922SmMinGroupedWork) {
    return Cutlass92ScheduleKind::k2Sm;
  }
  return Cutlass92ScheduleKind::k1Sm;
}

Cutlass92GroupedCounts load_cutlass92_grouped_counts(
    const int32_t* counts_by_expert,
    cudaStream_t stream) {
  int32_t counts_host[kNumLocalExperts];
  check_cuda(
      cudaMemcpyAsync(counts_host, counts_by_expert, sizeof(counts_host), cudaMemcpyDeviceToHost, stream),
      "cudaMemcpyAsync counts_by_expert");
  check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize counts_by_expert");

  Cutlass92GroupedCounts counts;
  for (int32_t expert = 0; expert < kNumLocalExperts; ++expert) {
    counts.max_count = counts_host[expert] > counts.max_count ? counts_host[expert] : counts.max_count;
    counts.total_live_slots += counts_host[expert];
  }
  counts.n_cutlass = round_up_cutlass92_n(counts.max_count);
  return counts;
}

Cutlass92GroupedCounts make_cutlass92_grouped_counts_no_sync(int32_t seq_len) {
  Cutlass92GroupedCounts counts;
  counts.max_count = seq_len;
  const int64_t total_live_slots = static_cast<int64_t>(seq_len) * kTopK;
  counts.total_live_slots = static_cast<int32_t>(std::min<int64_t>(
      std::max<int64_t>(total_live_slots, 0), std::numeric_limits<int32_t>::max()));
  counts.n_cutlass = round_up_cutlass92_n(seq_len);
  return counts;
}

Cutlass92GroupedCounts cutlass92_grouped_counts_for_launch(
    const int32_t* counts_by_expert,
    int32_t seq_len,
    cudaStream_t stream,
    bool exact_counts = false) {
  if (exact_counts || env_flag_is_one(kEnableCutlass92HostCountSyncEnv)) {
    return load_cutlass92_grouped_counts(counts_by_expert, stream);
  }
  return make_cutlass92_grouped_counts_no_sync(seq_len);
}

Cutlass92WeightPack pack_cutlass92_gemm1_weights(
    const uint8_t* weights,
    const float* scales,
    cudaStream_t stream) {
  Cutlass92WeightPack pack{
      std::make_shared<CachedDeviceAllocation>(checked_bytes(
          static_cast<int64_t>(kNumLocalExperts) * kGemm1OutSize * kHiddenSize,
          sizeof(uint8_t),
          "cutlass92_gemm1_packed_a")),
      std::make_shared<CachedDeviceAllocation>(checked_bytes(
          static_cast<int64_t>(kGemm1OutSize) * kHiddenSize,
          sizeof(uint8_t),
          "cutlass92_gemm1_packed_sfa"))};

  constexpr int32_t kThreads = 256;
  const int64_t total = static_cast<int64_t>(kNumLocalExperts) * kGemm1OutSize * kHiddenSize;
  const int32_t blocks = static_cast<int32_t>((total + kThreads - 1) / kThreads);
  pack_cutlass92_gemm1_weights_kernel<<<blocks, kThreads, 0, stream>>>(
      weights,
      scales,
      pack.packed_a->ptr,
      pack.packed_sfa->ptr);
  check_launch("pack_cutlass92_gemm1_weights_kernel");
  return pack;
}

Cutlass92WeightPack cached_cutlass92_gemm1_weights(
    const uint8_t* weights,
    const float* scales,
    int32_t device_index,
    cudaStream_t stream) {
  const DenseWeightCacheKey key{
      reinterpret_cast<uintptr_t>(weights),
      reinterpret_cast<uintptr_t>(scales),
      device_index,
      92};
  {
    std::lock_guard<std::mutex> lock(g_cutlass92_gemm1_weight_cache_mutex);
    const auto it = g_cutlass92_gemm1_weight_cache.find(key);
    if (it != g_cutlass92_gemm1_weight_cache.end()) {
      return it->second;
    }
  }

  Cutlass92WeightPack pack = pack_cutlass92_gemm1_weights(weights, scales, stream);

  std::lock_guard<std::mutex> lock(g_cutlass92_gemm1_weight_cache_mutex);
  const auto [it, inserted] = g_cutlass92_gemm1_weight_cache.emplace(key, pack);
  return it->second;
}

Cutlass92WeightPack pack_cutlass92_gemm2_weights(
    const uint8_t* weights,
    const float* scales,
    cudaStream_t stream) {
  Cutlass92WeightPack pack{
      std::make_shared<CachedDeviceAllocation>(checked_bytes(
          static_cast<int64_t>(kNumLocalExperts) * kHiddenSize * kIntermediateSize,
          sizeof(uint8_t),
          "cutlass92_gemm2_packed_a")),
      std::make_shared<CachedDeviceAllocation>(checked_bytes(
          static_cast<int64_t>(kHiddenSize) * kIntermediateSize,
          sizeof(uint8_t),
          "cutlass92_gemm2_packed_sfa"))};

  constexpr int32_t kThreads = 256;
  const int64_t total = static_cast<int64_t>(kNumLocalExperts) * kHiddenSize * kIntermediateSize;
  const int32_t blocks = static_cast<int32_t>((total + kThreads - 1) / kThreads);
  pack_cutlass92_gemm2_weights_kernel<<<blocks, kThreads, 0, stream>>>(
      weights,
      scales,
      pack.packed_a->ptr,
      pack.packed_sfa->ptr);
  check_launch("pack_cutlass92_gemm2_weights_kernel");
  return pack;
}

Cutlass92WeightPack cached_cutlass92_gemm2_weights(
    const uint8_t* weights,
    const float* scales,
    int32_t device_index,
    cudaStream_t stream) {
  const DenseWeightCacheKey key{
      reinterpret_cast<uintptr_t>(weights),
      reinterpret_cast<uintptr_t>(scales),
      device_index,
      93};
  {
    std::lock_guard<std::mutex> lock(g_cutlass92_gemm2_weight_cache_mutex);
    const auto it = g_cutlass92_gemm2_weight_cache.find(key);
    if (it != g_cutlass92_gemm2_weight_cache.end()) {
      return it->second;
    }
  }

  Cutlass92WeightPack pack = pack_cutlass92_gemm2_weights(weights, scales, stream);

  std::lock_guard<std::mutex> lock(g_cutlass92_gemm2_weight_cache_mutex);
  const auto [it, inserted] = g_cutlass92_gemm2_weight_cache.emplace(key, pack);
  return it->second;
}

template <typename Gemm>
Cutlass92Gemm1Result try_cutlass92_gemm1_impl(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const int32_t* compact_slot_ids,
    const int32_t* compact_row_to_local_expert,
    const int32_t* compact_row_to_expert_row,
    const int32_t* counts_by_expert,
    const int32_t* starts_by_expert,
    const int32_t* total_local_slots,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    const Cutlass92GroupedCounts& grouped_counts,
    Cutlass92ScheduleKind schedule,
    int32_t seq_len,
    int32_t total_slots,
    int32_t device_index,
    bool short_path,
    bool stateless_diagnostic,
    bool init_cutlass_launch_temp,
    InvocationIntegrityMonitor* integrity_monitor,
    cudaStream_t stream) {
  Cutlass92Gemm1Result result;
  result.counts = grouped_counts;
  result.schedule = schedule;
  result.used_retained_weight_state = !stateless_diagnostic;
  result.used_retained_launch_state = !stateless_diagnostic;
  const int32_t n_cutlass = grouped_counts.n_cutlass;
  if (n_cutlass <= 0 || grouped_counts.total_live_slots <= 0) {
    return result;
  }

  Cutlass92WeightPack weight_pack = stateless_diagnostic
      ? pack_cutlass92_gemm1_weights(gemm1_weights, gemm1_weights_scale, stream)
      : cached_cutlass92_gemm1_weights(gemm1_weights, gemm1_weights_scale, device_index, stream);
  auto launch_buffers = stateless_diagnostic
      ? std::make_shared<Cutlass92Gemm1LaunchBuffers>()
      : cached_cutlass92_gemm1_launch_buffers(device_index, stream);
  const size_t packed_b_bytes = checked_bytes(
      static_cast<int64_t>(kNumLocalExperts) * n_cutlass * kHiddenSize,
      sizeof(uint8_t),
      "gemm1_packed_b");
  ensure_cached_allocation(&launch_buffers->packed_b, packed_b_bytes);
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->packed_b->ptr,
        launch_buffers->packed_b->bytes,
        "cudaMemsetAsync integrity gemm1 packed_b");
    integrity_monitor->register_tail_guard(
        launch_buffers->packed_b->ptr,
        packed_b_bytes,
        launch_buffers->packed_b->bytes,
        "gemm1_packed_b_tail");
  }
  const int64_t sfb_stride = cutlass92_sfb_storage_elements(kGemm1OutSize, n_cutlass, kHiddenSize);
  const size_t packed_sfb_bytes = checked_bytes(
      static_cast<int64_t>(kNumLocalExperts) * sfb_stride,
      sizeof(uint8_t),
      "gemm1_packed_sfb");
  ensure_cached_allocation(&launch_buffers->packed_sfb, packed_sfb_bytes);
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->packed_sfb->ptr,
        launch_buffers->packed_sfb->bytes,
        "cudaMemsetAsync integrity gemm1 packed_sfb");
    integrity_monitor->register_tail_guard(
        launch_buffers->packed_sfb->ptr,
        packed_sfb_bytes,
        launch_buffers->packed_sfb->bytes,
        "gemm1_packed_sfb_tail");
  }
  ensure_cached_allocation(
      &launch_buffers->output,
      checked_bytes(static_cast<int64_t>(total_slots) * kGemm1OutSize, sizeof(__nv_bfloat16), "gemm1_out"));
  if (init_cutlass_launch_temp) {
    zero_device_region(launch_buffers->packed_b->ptr, launch_buffers->packed_b->bytes, stream, "cudaMemsetAsync full init gemm1 packed_b");
    zero_device_region(
        launch_buffers->packed_sfb->ptr,
        launch_buffers->packed_sfb->bytes,
        stream,
        "cudaMemsetAsync full init gemm1 packed_sfb");
    zero_device_region(launch_buffers->output->ptr, launch_buffers->output->bytes, stream, "cudaMemsetAsync full init gemm1 output");
  }
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    const size_t output_bytes =
        checked_bytes(static_cast<int64_t>(total_slots) * kGemm1OutSize, sizeof(__nv_bfloat16), "gemm1_out");
    integrity_monitor->poison_region(
        launch_buffers->output->ptr,
        launch_buffers->output->bytes,
        "cudaMemsetAsync integrity gemm1 output");
    integrity_monitor->register_tail_guard(
        launch_buffers->output->ptr,
        output_bytes,
        launch_buffers->output->bytes,
        "gemm1_output_tail");
  }
  ensure_cutlass92_ptr_arrays(launch_buffers.get());
  if (init_cutlass_launch_temp) {
    zero_device_region(launch_buffers->ptr_b->ptr, launch_buffers->ptr_b->bytes, stream, "cudaMemsetAsync full init gemm1 ptr_b");
    zero_device_region(
        launch_buffers->ptr_sfb->ptr,
        launch_buffers->ptr_sfb->bytes,
        stream,
        "cudaMemsetAsync full init gemm1 ptr_sfb");
    zero_device_region(launch_buffers->ptr_c->ptr, launch_buffers->ptr_c->bytes, stream, "cudaMemsetAsync full init gemm1 ptr_c");
    zero_device_region(launch_buffers->ptr_d->ptr, launch_buffers->ptr_d->bytes, stream, "cudaMemsetAsync full init gemm1 ptr_d");
  }
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->ptr_b->ptr,
        launch_buffers->ptr_b->bytes,
        "cudaMemsetAsync integrity gemm1 ptr_b");
    integrity_monitor->poison_region(
        launch_buffers->ptr_sfb->ptr,
        launch_buffers->ptr_sfb->bytes,
        "cudaMemsetAsync integrity gemm1 ptr_sfb");
    integrity_monitor->poison_region(
        launch_buffers->ptr_c->ptr,
        launch_buffers->ptr_c->bytes,
        "cudaMemsetAsync integrity gemm1 ptr_c");
    integrity_monitor->poison_region(
        launch_buffers->ptr_d->ptr,
        launch_buffers->ptr_d->bytes,
        "cudaMemsetAsync integrity gemm1 ptr_d");
  }
  init_cutlass92_gemm1_ptrs_kernel<<<1, 32, 0, stream>>>(
      starts_by_expert,
      reinterpret_cast<uint8_t*>(launch_buffers->packed_b->ptr),
      reinterpret_cast<uint8_t*>(launch_buffers->packed_sfb->ptr),
      reinterpret_cast<__nv_bfloat16*>(launch_buffers->output->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_b->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_sfb->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_c->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_d->ptr),
      sfb_stride,
      n_cutlass);
  check_launch("init_cutlass92_gemm1_ptrs_kernel");

  const dim3 pack_grid(total_slots, kCompactHiddenTiles);
  if (short_path) {
    pack_cutlass92_gemm1_activation_short_kernel<<<pack_grid, kShortCutlassGemm1PackThreads, 0, stream>>>(
        hidden_states,
        hidden_states_scale,
        compact_slot_ids,
        compact_row_to_local_expert,
        compact_row_to_expert_row,
        total_local_slots,
        reinterpret_cast<uint8_t*>(launch_buffers->packed_b->ptr),
        reinterpret_cast<uint8_t*>(launch_buffers->packed_sfb->ptr),
        sfb_stride,
        n_cutlass,
        seq_len);
    check_launch("pack_cutlass92_gemm1_activation_short_kernel");
  } else {
    pack_cutlass92_gemm1_activation_kernel<<<pack_grid, kCompactHiddenThreads, 0, stream>>>(
        hidden_states,
        hidden_states_scale,
        compact_slot_ids,
        compact_row_to_local_expert,
        compact_row_to_expert_row,
        total_local_slots,
        reinterpret_cast<uint8_t*>(launch_buffers->packed_b->ptr),
        reinterpret_cast<uint8_t*>(launch_buffers->packed_sfb->ptr),
        sfb_stride,
        n_cutlass,
        seq_len);
    check_launch("pack_cutlass92_gemm1_activation_kernel");
  }

  Gemm gemm;
  cutlass::KernelHardwareInfo hw_info;
  hw_info.device_id = device_index;
  hw_info.sm_count = cutlass::KernelHardwareInfo::query_device_multiprocessor_count(device_index);
  if (!cute::is_static_v<Cutlass92ClusterShape>) {
    const dim3 cluster_shape = cutlass92_cluster_shape(schedule);
    hw_info.cluster_shape = cluster_shape;
    hw_info.cluster_shape_fallback = cluster_shape;
  }

  typename Gemm::Arguments arguments;
  decltype(arguments.epilogue.thread) fusion_args;
  fusion_args.alpha = 1.0f;
  fusion_args.beta = 0.0f;
  fusion_args.alpha_ptr_array = nullptr;
  fusion_args.beta_ptr_array = nullptr;
  fusion_args.dAlpha = {cute::_0{}, cute::_0{}, 0};
  fusion_args.dBeta = {cute::_0{}, cute::_0{}, 0};

  typename Gemm::GemmKernel::TileSchedulerArguments scheduler;
  scheduler.raster_order = cutlass::gemm::kernel::detail::RasterOrderOptions::AlongN;

  using ArrayElementA = typename Gemm::GemmKernel::CollectiveMainloop::ArrayElementA;
  using ArrayElementB = typename Gemm::GemmKernel::CollectiveMainloop::ArrayElementB;
  arguments = typename Gemm::Arguments{
      cutlass::gemm::GemmUniversalMode::kGrouped,
      {kGemm1OutSize, n_cutlass, kHiddenSize, kNumLocalExperts, const_cast<int32_t*>(counts_by_expert)},
      {reinterpret_cast<const ArrayElementA*>(weight_pack.packed_a->ptr),
       reinterpret_cast<const ArrayElementB**>(launch_buffers->ptr_b->ptr),
       reinterpret_cast<const Cutlass92ElementSF*>(weight_pack.packed_sfa->ptr),
       reinterpret_cast<const Cutlass92ElementSF**>(launch_buffers->ptr_sfb->ptr)},
      {fusion_args,
       reinterpret_cast<const Cutlass92ElementC**>(launch_buffers->ptr_c->ptr),
       nullptr,
       reinterpret_cast<Cutlass92ElementC**>(launch_buffers->ptr_d->ptr),
       nullptr},
      hw_info,
      scheduler};

  if (gemm.can_implement(arguments) != cutlass::Status::kSuccess) {
    return result;
  }

  const size_t workspace_bytes = Gemm::get_workspace_size(arguments);
  ensure_cached_allocation(&launch_buffers->workspace, workspace_bytes);
  if (init_cutlass_launch_temp) {
    zero_device_region(
        launch_buffers->workspace->ptr,
        launch_buffers->workspace->bytes,
        stream,
        "cudaMemsetAsync full init gemm1 workspace");
  }
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->workspace->ptr,
        launch_buffers->workspace->bytes,
        "cudaMemsetAsync integrity gemm1 workspace");
    integrity_monitor->register_tail_guard(
        launch_buffers->workspace->ptr,
        workspace_bytes,
        launch_buffers->workspace->bytes,
        "gemm1_workspace_tail");
  }
  if (gemm.initialize(arguments, reinterpret_cast<uint8_t*>(launch_buffers->workspace->ptr), stream) !=
      cutlass::Status::kSuccess) {
    return result;
  }
  if (gemm.run(stream, nullptr, cutlass92_launch_with_pdl()) != cutlass::Status::kSuccess) {
    return result;
  }
  check_launch("Cutlass92Gemm1");

  result.ok = true;
  result.output = launch_buffers->output;
  return result;
}

Cutlass92Gemm1Result try_cutlass92_gemm1(
    const uint8_t* hidden_states,
    const float* hidden_states_scale,
    const int32_t* compact_slot_ids,
    const int32_t* compact_row_to_local_expert,
    const int32_t* compact_row_to_expert_row,
    const int32_t* counts_by_expert,
    const int32_t* starts_by_expert,
    const int32_t* total_local_slots,
    const uint8_t* gemm1_weights,
    const float* gemm1_weights_scale,
    int32_t seq_len,
    int32_t total_slots,
    int32_t device_index,
    bool short_path,
    bool stateless_diagnostic,
    bool init_cutlass_launch_temp,
    InvocationIntegrityMonitor* integrity_monitor,
    cudaStream_t stream) {
  Cutlass92Gemm1Result result;
  if (!device_supports_cutlass92(device_index) || total_slots <= 0) {
    return result;
  }

  const Cutlass92GroupedCounts grouped_counts =
      cutlass92_grouped_counts_for_launch(counts_by_expert, seq_len, stream, short_path);
  result.counts = grouped_counts;
  if (grouped_counts.n_cutlass <= 0 || grouped_counts.total_live_slots <= 0) {
    return result;
  }

  const Cutlass92ScheduleKind schedule = select_cutlass92_schedule(grouped_counts, seq_len);
  if (schedule == Cutlass92ScheduleKind::k2Sm) {
    Cutlass92Gemm1Result two_sm = try_cutlass92_gemm1_impl<Cutlass92Gemm2SM>(
        hidden_states,
        hidden_states_scale,
        compact_slot_ids,
        compact_row_to_local_expert,
        compact_row_to_expert_row,
        counts_by_expert,
        starts_by_expert,
        total_local_slots,
        gemm1_weights,
        gemm1_weights_scale,
        grouped_counts,
        schedule,
        seq_len,
        total_slots,
        device_index,
        short_path,
        stateless_diagnostic,
        init_cutlass_launch_temp,
        integrity_monitor,
        stream);
    if (two_sm.ok || env_flag_is_one(kForceCutlass922SmEnv)) {
      return two_sm;
    }
  }

  return try_cutlass92_gemm1_impl<Cutlass92Gemm1SM>(
      hidden_states,
      hidden_states_scale,
      compact_slot_ids,
      compact_row_to_local_expert,
      compact_row_to_expert_row,
      counts_by_expert,
      starts_by_expert,
      total_local_slots,
      gemm1_weights,
      gemm1_weights_scale,
      grouped_counts,
      Cutlass92ScheduleKind::k1Sm,
      seq_len,
      total_slots,
      device_index,
      short_path,
      stateless_diagnostic,
      init_cutlass_launch_temp,
      integrity_monitor,
      stream);
}

template <typename Gemm>
Cutlass92Gemm2Result try_cutlass92_gemm2_impl(
    const __nv_bfloat16* gemm1_out,
    const int32_t* compact_row_to_local_expert,
    const int32_t* compact_row_to_expert_row,
    const int32_t* counts_by_expert,
    const int32_t* starts_by_expert,
    const int32_t* total_local_slots,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const Cutlass92GroupedCounts& known_counts,
    Cutlass92ScheduleKind schedule,
    int32_t total_slots,
    int32_t device_index,
    bool short_path,
    bool stateless_diagnostic,
    bool init_cutlass_launch_temp,
    InvocationIntegrityMonitor* integrity_monitor,
    cudaStream_t stream) {
  Cutlass92Gemm2Result result;
  result.used_retained_weight_state = !stateless_diagnostic;
  result.used_retained_launch_state = !stateless_diagnostic;
  Cutlass92GroupedCounts grouped_counts = known_counts;
  const int32_t n_cutlass = grouped_counts.n_cutlass;
  if (n_cutlass <= 0 || grouped_counts.total_live_slots <= 0) {
    return result;
  }

  Cutlass92WeightPack weight_pack = stateless_diagnostic
      ? pack_cutlass92_gemm2_weights(gemm2_weights, gemm2_weights_scale, stream)
      : cached_cutlass92_gemm2_weights(gemm2_weights, gemm2_weights_scale, device_index, stream);
  auto launch_buffers = stateless_diagnostic
      ? std::make_shared<Cutlass92Gemm2LaunchBuffers>()
      : cached_cutlass92_gemm2_launch_buffers(device_index, stream);
  const size_t packed_b_bytes = checked_bytes(
      static_cast<int64_t>(kNumLocalExperts) * n_cutlass * kIntermediateSize,
      sizeof(uint8_t),
      "gemm2_packed_b");
  ensure_cached_allocation(&launch_buffers->packed_b, packed_b_bytes);
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->packed_b->ptr,
        launch_buffers->packed_b->bytes,
        "cudaMemsetAsync integrity gemm2 packed_b");
    integrity_monitor->register_tail_guard(
        launch_buffers->packed_b->ptr,
        packed_b_bytes,
        launch_buffers->packed_b->bytes,
        "gemm2_packed_b_tail");
  }
  const int64_t sfb_stride = cutlass92_sfb_storage_elements(kHiddenSize, n_cutlass, kIntermediateSize);
  const size_t packed_sfb_bytes = checked_bytes(
      static_cast<int64_t>(kNumLocalExperts) * sfb_stride,
      sizeof(uint8_t),
      "gemm2_packed_sfb");
  ensure_cached_allocation(&launch_buffers->packed_sfb, packed_sfb_bytes);
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->packed_sfb->ptr,
        launch_buffers->packed_sfb->bytes,
        "cudaMemsetAsync integrity gemm2 packed_sfb");
    integrity_monitor->register_tail_guard(
        launch_buffers->packed_sfb->ptr,
        packed_sfb_bytes,
        launch_buffers->packed_sfb->bytes,
        "gemm2_packed_sfb_tail");
  }
  ensure_cached_allocation(
      &launch_buffers->output,
      checked_bytes(static_cast<int64_t>(total_slots) * kHiddenSize, sizeof(__nv_bfloat16), "expert_output"));
  if (init_cutlass_launch_temp) {
    zero_device_region(launch_buffers->packed_b->ptr, launch_buffers->packed_b->bytes, stream, "cudaMemsetAsync full init gemm2 packed_b");
    zero_device_region(
        launch_buffers->packed_sfb->ptr,
        launch_buffers->packed_sfb->bytes,
        stream,
        "cudaMemsetAsync full init gemm2 packed_sfb");
    zero_device_region(
        launch_buffers->output->ptr,
        launch_buffers->output->bytes,
        stream,
        "cudaMemsetAsync full init gemm2 output");
  }
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    const size_t output_bytes =
        checked_bytes(static_cast<int64_t>(total_slots) * kHiddenSize, sizeof(__nv_bfloat16), "expert_output");
    integrity_monitor->poison_region(
        launch_buffers->output->ptr,
        launch_buffers->output->bytes,
        "cudaMemsetAsync integrity gemm2 output");
    integrity_monitor->register_tail_guard(
        launch_buffers->output->ptr,
        output_bytes,
        launch_buffers->output->bytes,
        "gemm2_output_tail");
  }
  ensure_cutlass92_ptr_arrays(launch_buffers.get());
  if (init_cutlass_launch_temp) {
    zero_device_region(launch_buffers->ptr_b->ptr, launch_buffers->ptr_b->bytes, stream, "cudaMemsetAsync full init gemm2 ptr_b");
    zero_device_region(
        launch_buffers->ptr_sfb->ptr,
        launch_buffers->ptr_sfb->bytes,
        stream,
        "cudaMemsetAsync full init gemm2 ptr_sfb");
    zero_device_region(launch_buffers->ptr_c->ptr, launch_buffers->ptr_c->bytes, stream, "cudaMemsetAsync full init gemm2 ptr_c");
    zero_device_region(launch_buffers->ptr_d->ptr, launch_buffers->ptr_d->bytes, stream, "cudaMemsetAsync full init gemm2 ptr_d");
  }
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->ptr_b->ptr,
        launch_buffers->ptr_b->bytes,
        "cudaMemsetAsync integrity gemm2 ptr_b");
    integrity_monitor->poison_region(
        launch_buffers->ptr_sfb->ptr,
        launch_buffers->ptr_sfb->bytes,
        "cudaMemsetAsync integrity gemm2 ptr_sfb");
    integrity_monitor->poison_region(
        launch_buffers->ptr_c->ptr,
        launch_buffers->ptr_c->bytes,
        "cudaMemsetAsync integrity gemm2 ptr_c");
    integrity_monitor->poison_region(
        launch_buffers->ptr_d->ptr,
        launch_buffers->ptr_d->bytes,
        "cudaMemsetAsync integrity gemm2 ptr_d");
  }
  init_cutlass92_gemm2_ptrs_kernel<<<1, 32, 0, stream>>>(
      starts_by_expert,
      reinterpret_cast<uint8_t*>(launch_buffers->packed_b->ptr),
      reinterpret_cast<uint8_t*>(launch_buffers->packed_sfb->ptr),
      reinterpret_cast<__nv_bfloat16*>(launch_buffers->output->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_b->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_sfb->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_c->ptr),
      reinterpret_cast<uintptr_t*>(launch_buffers->ptr_d->ptr),
      sfb_stride,
      n_cutlass);
  check_launch("init_cutlass92_gemm2_ptrs_kernel");

  const dim3 pack_grid(total_slots, kIntermediateBlocks);
  if (short_path) {
    fused_swiglu_pack_cutlass92_gemm2_activation_short_kernel<<<pack_grid, kShortCutlassGemm2PackThreads, 0, stream>>>(
        gemm1_out,
        compact_row_to_local_expert,
        compact_row_to_expert_row,
        total_local_slots,
        reinterpret_cast<uint8_t*>(launch_buffers->packed_b->ptr),
        reinterpret_cast<uint8_t*>(launch_buffers->packed_sfb->ptr),
        sfb_stride,
        n_cutlass);
    check_launch("fused_swiglu_pack_cutlass92_gemm2_activation_short_kernel");
  } else {
    fused_swiglu_pack_cutlass92_gemm2_activation_kernel<<<pack_grid, kBlockSize, 0, stream>>>(
        gemm1_out,
        compact_row_to_local_expert,
        compact_row_to_expert_row,
        total_local_slots,
        reinterpret_cast<uint8_t*>(launch_buffers->packed_b->ptr),
        reinterpret_cast<uint8_t*>(launch_buffers->packed_sfb->ptr),
        sfb_stride,
        n_cutlass);
    check_launch("fused_swiglu_pack_cutlass92_gemm2_activation_kernel");
  }

  Gemm gemm;
  cutlass::KernelHardwareInfo hw_info;
  hw_info.device_id = device_index;
  hw_info.sm_count = cutlass::KernelHardwareInfo::query_device_multiprocessor_count(device_index);
  if (!cute::is_static_v<Cutlass92ClusterShape>) {
    const dim3 cluster_shape = cutlass92_cluster_shape(schedule);
    hw_info.cluster_shape = cluster_shape;
    hw_info.cluster_shape_fallback = cluster_shape;
  }

  typename Gemm::Arguments arguments;
  decltype(arguments.epilogue.thread) fusion_args;
  fusion_args.alpha = 1.0f;
  fusion_args.beta = 0.0f;
  fusion_args.alpha_ptr_array = nullptr;
  fusion_args.beta_ptr_array = nullptr;
  fusion_args.dAlpha = {cute::_0{}, cute::_0{}, 0};
  fusion_args.dBeta = {cute::_0{}, cute::_0{}, 0};

  typename Gemm::GemmKernel::TileSchedulerArguments scheduler;
  scheduler.raster_order = cutlass::gemm::kernel::detail::RasterOrderOptions::AlongN;

  using ArrayElementA = typename Gemm::GemmKernel::CollectiveMainloop::ArrayElementA;
  using ArrayElementB = typename Gemm::GemmKernel::CollectiveMainloop::ArrayElementB;
  arguments = typename Gemm::Arguments{
      cutlass::gemm::GemmUniversalMode::kGrouped,
      {kHiddenSize, n_cutlass, kIntermediateSize, kNumLocalExperts, const_cast<int32_t*>(counts_by_expert)},
      {reinterpret_cast<const ArrayElementA*>(weight_pack.packed_a->ptr),
       reinterpret_cast<const ArrayElementB**>(launch_buffers->ptr_b->ptr),
       reinterpret_cast<const Cutlass92ElementSF*>(weight_pack.packed_sfa->ptr),
       reinterpret_cast<const Cutlass92ElementSF**>(launch_buffers->ptr_sfb->ptr)},
      {fusion_args,
       reinterpret_cast<const Cutlass92ElementC**>(launch_buffers->ptr_c->ptr),
       nullptr,
       reinterpret_cast<Cutlass92ElementC**>(launch_buffers->ptr_d->ptr),
       nullptr},
      hw_info,
      scheduler};

  if (gemm.can_implement(arguments) != cutlass::Status::kSuccess) {
    return result;
  }

  const size_t workspace_bytes = Gemm::get_workspace_size(arguments);
  ensure_cached_allocation(&launch_buffers->workspace, workspace_bytes);
  if (init_cutlass_launch_temp) {
    zero_device_region(
        launch_buffers->workspace->ptr,
        launch_buffers->workspace->bytes,
        stream,
        "cudaMemsetAsync full init gemm2 workspace");
  }
  if (integrity_monitor != nullptr && integrity_monitor->enabled()) {
    integrity_monitor->poison_region(
        launch_buffers->workspace->ptr,
        launch_buffers->workspace->bytes,
        "cudaMemsetAsync integrity gemm2 workspace");
    integrity_monitor->register_tail_guard(
        launch_buffers->workspace->ptr,
        workspace_bytes,
        launch_buffers->workspace->bytes,
        "gemm2_workspace_tail");
  }
  if (gemm.initialize(arguments, reinterpret_cast<uint8_t*>(launch_buffers->workspace->ptr), stream) !=
      cutlass::Status::kSuccess) {
    return result;
  }
  if (gemm.run(stream, nullptr, cutlass92_launch_with_pdl()) != cutlass::Status::kSuccess) {
    return result;
  }
  check_launch("Cutlass92Gemm2");

  result.ok = true;
  result.output = launch_buffers->output;
  return result;
}

Cutlass92Gemm2Result try_cutlass92_gemm2(
    const __nv_bfloat16* gemm1_out,
    const int32_t* compact_row_to_local_expert,
    const int32_t* compact_row_to_expert_row,
    const int32_t* counts_by_expert,
    const int32_t* starts_by_expert,
    const int32_t* total_local_slots,
    const uint8_t* gemm2_weights,
    const float* gemm2_weights_scale,
    const Cutlass92GroupedCounts& known_counts,
    Cutlass92ScheduleKind known_schedule,
    int32_t total_slots,
    int32_t device_index,
    bool short_path,
    bool stateless_diagnostic,
    bool init_cutlass_launch_temp,
    InvocationIntegrityMonitor* integrity_monitor,
    cudaStream_t stream) {
  Cutlass92Gemm2Result result;
  if (!device_supports_cutlass92(device_index) || total_slots <= 0) {
    return result;
  }

  Cutlass92GroupedCounts grouped_counts = known_counts;
  if (grouped_counts.n_cutlass <= 0 || grouped_counts.total_live_slots <= 0) {
    grouped_counts = cutlass92_grouped_counts_for_launch(
        counts_by_expert,
        total_slots / kTopK,
        stream,
        short_path);
  }
  if (grouped_counts.n_cutlass <= 0 || grouped_counts.total_live_slots <= 0) {
    return result;
  }

  Cutlass92ScheduleKind schedule = known_schedule;
  if (known_counts.n_cutlass <= 0) {
    schedule = select_cutlass92_schedule(grouped_counts, total_slots / kTopK);
  }
  if (schedule == Cutlass92ScheduleKind::k2Sm) {
    Cutlass92Gemm2Result two_sm = try_cutlass92_gemm2_impl<Cutlass92Gemm2SM>(
        gemm1_out,
        compact_row_to_local_expert,
        compact_row_to_expert_row,
        counts_by_expert,
        starts_by_expert,
        total_local_slots,
        gemm2_weights,
        gemm2_weights_scale,
        grouped_counts,
        schedule,
        total_slots,
        device_index,
        short_path,
        stateless_diagnostic,
        init_cutlass_launch_temp,
        integrity_monitor,
        stream);
    if (two_sm.ok || env_flag_is_one(kForceCutlass922SmEnv)) {
      return two_sm;
    }
  }

  return try_cutlass92_gemm2_impl<Cutlass92Gemm1SM>(
      gemm1_out,
      compact_row_to_local_expert,
      compact_row_to_expert_row,
      counts_by_expert,
      starts_by_expert,
      total_local_slots,
      gemm2_weights,
      gemm2_weights_scale,
      grouped_counts,
      Cutlass92ScheduleKind::k1Sm,
      total_slots,
      device_index,
      short_path,
      stateless_diagnostic,
      init_cutlass_launch_temp,
      integrity_monitor,
      stream);
}
#endif

void Kernel(
    tvm::ffi::TensorView routing_logits,
    tvm::ffi::TensorView routing_bias,
    tvm::ffi::TensorView hidden_states,
    tvm::ffi::TensorView hidden_states_scale,
    tvm::ffi::TensorView gemm1_weights,
    tvm::ffi::TensorView gemm1_weights_scale,
    tvm::ffi::TensorView gemm2_weights,
    tvm::ffi::TensorView gemm2_weights_scale,
    int32_t local_expert_offset,
    float routed_scaling_factor,
    tvm::ffi::TensorView output) {
  if (local_expert_offset < 0 || local_expert_offset + kNumLocalExperts > kNumExpertsGlobal) {
    TVM_FFI_THROW(ValueError)
        << "local_expert_offset must select a valid 32-expert window within 256 experts";
  }
  if (!std::isfinite(routed_scaling_factor)) {
    TVM_FFI_THROW(ValueError) << "routed_scaling_factor must be finite";
  }

  validate_inputs(
      routing_logits,
      routing_bias,
      hidden_states,
      hidden_states_scale,
      gemm1_weights,
      gemm1_weights_scale,
      gemm2_weights,
      gemm2_weights_scale,
      output);

  const int64_t seq_len = routing_logits.size(0);
  if (seq_len == 0) {
    return;
  }

  const DLDevice device = routing_logits.device();
  CudaDeviceGuard device_guard(device.device_id);
  cudaStream_t caller_stream = static_cast<cudaStream_t>(
      TVMFFIEnvGetStream(device.device_type, device.device_id));
  cudaStream_t stream = caller_stream;
  const bool private_stream_diagnostic = private_stream_execution_diagnostic_enabled();
  const bool device_fence_diagnostic = device_wide_fence_diagnostic_enabled();
  ScopedCudaEvent caller_stream_ready_event;
  ScopedCudaEvent private_stream_done_event;
  if (device_fence_diagnostic) {
    check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize device fence pre");
  }
  if (private_stream_diagnostic) {
    stream = cached_private_execution_stream(device.device_id);
    check_cuda(cudaEventRecord(caller_stream_ready_event.get(), caller_stream), "cudaEventRecord caller_stream_ready");
    check_cuda(
        cudaStreamWaitEvent(stream, caller_stream_ready_event.get(), 0),
        "cudaStreamWaitEvent private stream waits on caller");
  }

  const int32_t seq_len_i32 = static_cast<int32_t>(seq_len);
  const int32_t total_slots = seq_len_i32 * kTopK;
  const int32_t total_output = seq_len_i32 * kHiddenSize;
  const int64_t total_slots_i64 = static_cast<int64_t>(total_slots);
  const int64_t total_output_i64 = static_cast<int64_t>(total_output);
  const bool integrity_diagnostic = invocation_integrity_diagnostic_enabled();
  const bool reusable_temp_diagnostic = reusable_temp_diagnostic_enabled();
  const bool fp32_finalization_diagnostic = fp32_finalization_diagnostic_enabled();
  const bool post_gemm2_materialization_diagnostic = post_gemm2_materialization_diagnostic_enabled();
  const TempStateInitConfig temp_init = temp_state_init_config();
  const Cutlass92PerturbationConfig perturbation = cutlass92_perturbation_config();
  const Gemm2RefComponentConfig gemm2_ref_components = gemm2_ref_component_config();
  const PrepareReferenceComponentConfig prepare_reference_components = prepare_reference_component_config();
  const bool use_short_seq_metadata_fastpath =
      seq_len > 0 && seq_len <= kCompactScalarSmallSeqLenGate && !env_flag_is_one(kDisableCompactScalarEnv);
  const bool use_compact_path = should_use_compact_scalar_path(seq_len);
  const bool use_compact_execution = use_compact_path || use_short_seq_metadata_fastpath;
  const bool use_compact_workspace = use_compact_execution;
  const bool short_cutlass92_runtime_active =
      use_short_seq_metadata_fastpath && short_cutlass92_runtime_enabled(seq_len, device.device_id);
  const bool cutlass_runtime_active =
      (use_compact_path || short_cutlass92_runtime_active)
#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
      && (cutlass92_runtime_enabled(seq_len) || short_cutlass92_runtime_active)
#else
      && false
#endif
      ;
  const bool cutlass92_gemm2_active =
      cutlass_runtime_active &&
      (short_cutlass92_runtime_active || !env_flag_is_one(kDisableCutlass92Gemm2Env));
  const bool use_reusable_temp =
      promoted_reusable_temp_enabled(cutlass_runtime_active, reusable_temp_diagnostic);
  const bool use_fp32_finalization =
      promoted_fp32_finalization_enabled(cutlass_runtime_active, fp32_finalization_diagnostic);
  const bool stream_trace_enabled =
      private_stream_diagnostic || integrity_diagnostic || reusable_temp_diagnostic ||
      post_gemm2_materialization_diagnostic || temp_init.enabled ||
      perturbation.enabled || gemm2_ref_components.enabled || prepare_reference_components.enabled ||
      cutlass92_path_trace_enabled();
  const uint64_t invocation_id =
      stream_trace_enabled ? (g_kernel_invocation_counter.fetch_add(1, std::memory_order_relaxed) + 1) : 0;
  ExecutionStreamTrace execution_trace{
      invocation_id,
      device.device_id,
      caller_stream,
      stream,
      seq_len_i32,
      private_stream_diagnostic,
      device_fence_diagnostic,
      use_reusable_temp,
      temp_init.enabled,
      false,
      false,
      false,
      false,
      false,
      false,
      false};

  InvocationIntegrityMonitor integrity_monitor(
      integrity_diagnostic,
      invocation_id,
      device.device_id,
      caller_stream,
      stream,
      seq_len_i32,
      use_compact_execution,
      use_short_seq_metadata_fastpath,
      cutlass_runtime_active,
      private_stream_diagnostic,
      device_fence_diagnostic);

  size_t workspace_bytes = 0;
  add_aligned_bytes(&workspace_bytes, total_slots_i64, sizeof(int32_t), "topk_idx", integrity_diagnostic);
  add_aligned_bytes(&workspace_bytes, total_slots_i64, sizeof(float), "topk_weight", integrity_diagnostic);
  if (use_compact_workspace) {
    add_aligned_bytes(&workspace_bytes, kNumLocalExperts, sizeof(int32_t), "counts_by_expert", integrity_diagnostic);
    add_aligned_bytes(
        &workspace_bytes,
        static_cast<int64_t>(kNumLocalExperts) * total_slots_i64,
        sizeof(int32_t),
        "slot_ids_by_expert",
        integrity_diagnostic);
    add_aligned_bytes(
        &workspace_bytes,
        static_cast<int64_t>(kNumLocalExperts) * total_slots_i64,
        sizeof(float),
        "weights_by_expert",
        integrity_diagnostic);
    add_aligned_bytes(&workspace_bytes, total_slots_i64, sizeof(int32_t), "slot_to_compact_row", integrity_diagnostic);
    add_aligned_bytes(&workspace_bytes, kNumLocalExperts, sizeof(int32_t), "starts_by_expert", integrity_diagnostic);
    add_aligned_bytes(&workspace_bytes, kNumLocalExperts, sizeof(int32_t), "offsets_by_expert", integrity_diagnostic);
    add_aligned_bytes(&workspace_bytes, 1, sizeof(int32_t), "total_local_slots", integrity_diagnostic);
    add_aligned_bytes(&workspace_bytes, total_slots_i64, sizeof(int32_t), "compact_slot_ids", integrity_diagnostic);
    add_aligned_bytes(&workspace_bytes, total_slots_i64, sizeof(float), "compact_weights", integrity_diagnostic);
    add_aligned_bytes(
        &workspace_bytes,
        total_slots_i64 * kIntermediateSize,
        sizeof(float),
        "compact_gated",
        integrity_diagnostic);
  } else {
    add_aligned_bytes(&workspace_bytes, total_slots_i64 * kIntermediateSize, sizeof(float), "gated", integrity_diagnostic);
  }
  add_aligned_bytes(&workspace_bytes, total_output_i64, sizeof(float), "output_fp32", integrity_diagnostic);

  std::shared_ptr<ReusableTempBuffers> reusable_temp_buffers;
  if (use_reusable_temp) {
    reusable_temp_buffers = cached_reusable_temp_buffers(device.device_id, stream);
    const ReusableBufferAcquireResult workspace_buffer =
        reusable_temp_buffers->workspace.ensure(workspace_bytes, stream);
    execution_trace.workspace_reused = workspace_buffer.reused;
    execution_trace.workspace_grew = workspace_buffer.grew;
    if (temp_init.workspace) {
      execution_trace.init_workspace_family = true;
      zero_device_region(
          workspace_buffer.ptr,
          workspace_buffer.bytes,
          stream,
          "cudaMemsetAsync full init reusable workspace");
    }
    CudaWorkspace retained_workspace(workspace_buffer.ptr, workspace_buffer.bytes, stream, integrity_diagnostic);
    maybe_log_execution_stream_trace(stream_trace_enabled, "start", execution_trace, "unassigned");
    integrity_monitor.log_start();
    int32_t* topk_idx = retained_workspace.alloc<int32_t>(total_slots_i64, "topk_idx");
    float* topk_weight = retained_workspace.alloc<float>(total_slots_i64, "topk_weight");

    int32_t* counts_by_expert = nullptr;
    int32_t* slot_ids_by_expert = nullptr;
    float* weights_by_expert = nullptr;
    int32_t* slot_to_compact_row = nullptr;
    int32_t* starts_by_expert = nullptr;
    int32_t* offsets_by_expert = nullptr;
    int32_t* total_local_slots = nullptr;
    int32_t* compact_slot_ids = nullptr;
    float* compact_weights = nullptr;
    float* gated = nullptr;
    if (use_compact_workspace) {
      counts_by_expert = retained_workspace.alloc<int32_t>(kNumLocalExperts, "counts_by_expert");
      slot_ids_by_expert = retained_workspace.alloc<int32_t>(
          static_cast<int64_t>(kNumLocalExperts) * total_slots_i64,
          "slot_ids_by_expert");
      weights_by_expert = retained_workspace.alloc<float>(
          static_cast<int64_t>(kNumLocalExperts) * total_slots_i64,
          "weights_by_expert");
      slot_to_compact_row = retained_workspace.alloc<int32_t>(total_slots_i64, "slot_to_compact_row");
      starts_by_expert = retained_workspace.alloc<int32_t>(kNumLocalExperts, "starts_by_expert");
      offsets_by_expert = retained_workspace.alloc<int32_t>(kNumLocalExperts, "offsets_by_expert");
      total_local_slots = retained_workspace.alloc<int32_t>(1, "total_local_slots");
      compact_slot_ids = retained_workspace.alloc<int32_t>(total_slots_i64, "compact_slot_ids");
      compact_weights = retained_workspace.alloc<float>(total_slots_i64, "compact_weights");
      gated = retained_workspace.alloc<float>(total_slots_i64 * kIntermediateSize, "compact_gated");
    } else {
      gated = retained_workspace.alloc<float>(total_slots_i64 * kIntermediateSize, "gated");
    }
    float* output_fp32 = retained_workspace.alloc<float>(total_output_i64, "output_fp32");

    const size_t output_fp32_bytes = checked_bytes(total_output_i64, sizeof(float), "output_fp32");
    check_cuda(cudaMemsetAsync(output_fp32, 0, output_fp32_bytes, stream), "cudaMemsetAsync output_fp32");
    if (integrity_monitor.enabled()) {
      integrity_monitor.poison_region(
          output.data_ptr(),
          checked_bytes(total_output_i64, sizeof(__nv_bfloat16), "output"),
          "cudaMemsetAsync integrity output");
    }

    auto finalize_integrity = [&](const char* path) {
      maybe_log_execution_stream_trace(stream_trace_enabled, "end", execution_trace, path);
      if (!integrity_monitor.enabled()) {
        return;
      }
      integrity_monitor.set_path(path);
      integrity_monitor.synchronize_and_validate();
      retained_workspace.validate_guards();
      integrity_monitor.log_end();
    };
    const char* final_path = use_compact_execution ? "compact_fallback" : "dense_fallback";
    bool cutlass_completed = false;
    const bool use_short_cutlass92_path = short_cutlass92_runtime_active;

    constexpr int32_t kThreads = 128;
    launch_route_topk(
        use_short_cutlass92_path,
        static_cast<const float*>(routing_logits.data_ptr()),
        static_cast<const __nv_bfloat16*>(routing_bias.data_ptr()),
        topk_idx,
        topk_weight,
        local_expert_offset,
        routed_scaling_factor,
        seq_len_i32,
        stream);

    if (use_short_seq_metadata_fastpath && !use_short_cutlass92_path) {
      launch_short_compact_metadata(
          topk_idx,
          topk_weight,
          counts_by_expert,
          starts_by_expert,
          offsets_by_expert,
          compact_slot_ids,
          slot_to_compact_row,
          compact_weights,
          total_local_slots,
          local_expert_offset,
          total_slots,
          stream);
    }

    if (use_compact_execution) {
      constexpr int32_t kMetadataThreads = 256;
      const dim3 metadata_grid((total_slots + kMetadataThreads - 1) / kMetadataThreads, kNumLocalExperts);
      if (use_compact_path || use_short_cutlass92_path) {
        check_cuda(
            cudaMemsetAsync(
                counts_by_expert,
                0,
                checked_bytes(kNumLocalExperts, sizeof(int32_t), "counts_by_expert"),
                stream),
            "cudaMemsetAsync counts_by_expert");

        const int32_t bin_blocks = (total_slots + kMetadataThreads - 1) / kMetadataThreads;
        build_local_expert_bins_kernel<<<bin_blocks, kMetadataThreads, 0, stream>>>(
            topk_idx,
            topk_weight,
            slot_ids_by_expert,
            weights_by_expert,
            counts_by_expert,
            slot_to_compact_row,
            local_expert_offset,
            total_slots);
        check_launch("build_local_expert_bins_kernel");

        build_expert_offsets_kernel<<<1, 1, 0, stream>>>(
            counts_by_expert,
            starts_by_expert,
            offsets_by_expert,
            total_local_slots);
        check_launch("build_expert_offsets_kernel");

        compact_expert_metadata_kernel<<<metadata_grid, kMetadataThreads, 0, stream>>>(
            slot_ids_by_expert,
            weights_by_expert,
            counts_by_expert,
            starts_by_expert,
            compact_slot_ids,
            slot_to_compact_row,
            compact_weights,
            total_slots);
        check_launch("compact_expert_metadata_kernel");
        maybe_validate_compact_metadata(
            topk_idx,
            compact_slot_ids,
            slot_to_compact_row,
            total_local_slots,
            local_expert_offset,
            total_slots,
            stream);

#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
        Cutlass92InvocationTrace cutlass92_trace;
        cutlass92_trace.invocation_id = invocation_id;
        cutlass92_trace.runtime_enabled = cutlass_runtime_active;
        cutlass92_trace.fp32_finalization_active = use_fp32_finalization;
        cutlass92_trace.post_gemm2_materialization_active = post_gemm2_materialization_diagnostic;
        cutlass92_trace.gemm2_ref_component_bisection_active = gemm2_ref_components.enabled;
        cutlass92_trace.gemm2_ref_prepare_reference_active = gemm2_ref_components.prepare_reference;
        cutlass92_trace.gemm2_ref_compare_tail_active = gemm2_ref_components.compare_tail;
        cutlass92_trace.prepare_reference_component_bisection_active = prepare_reference_components.enabled;
        cutlass92_trace.prepare_reference_zero_output_active = prepare_reference_components.zero_output_fp32;
        cutlass92_trace.prepare_reference_gemm1_active = prepare_reference_components.fallback_gemm1_prepare;
        cutlass92_trace.prepare_reference_gemm2_accumulation_active =
            prepare_reference_components.fallback_gemm2_accumulation;
        cutlass92_trace.stateless_diagnostic = cutlass92_stateless_diagnostic_enabled();
        cutlass92_trace.full_temp_init_active = temp_init.enabled;
        cutlass92_trace.stage_validation_active = perturbation.full_stage_validation;
        cutlass92_trace.perturbation_bisection_active =
            perturbation.enabled && !perturbation.full_stage_validation;
        cutlass92_trace.private_stream_active = private_stream_diagnostic;
        cutlass92_trace.device_fence_active = device_fence_diagnostic;
        cutlass92_trace.caller_stream = reinterpret_cast<uintptr_t>(caller_stream);
        cutlass92_trace.execution_stream = reinterpret_cast<uintptr_t>(stream);
        if (cutlass92_trace.runtime_enabled) {
          cutlass92_trace.init_cutlass_launch_family = temp_init.cutlass_launch;
          cutlass92_trace.perturb_metadata_hostcopy_sync = perturbation.metadata_hostcopy_sync;
          cutlass92_trace.perturb_gemm1_reference_compare = perturbation.gemm1_reference_compare;
          cutlass92_trace.perturb_gemm2_reference_compare = perturbation.gemm2_reference_compare;
          cutlass92_trace.perturb_sync_after_metadata = perturbation.sync_after_metadata;
          cutlass92_trace.perturb_sync_after_gemm1 = perturbation.sync_after_gemm1;
          cutlass92_trace.perturb_sync_after_gemm2 = perturbation.sync_after_gemm2;
          const ReusableBufferAcquireResult row_owner_local =
              reusable_temp_buffers->row_owner_local_expert.ensure(
                  checked_bytes(total_slots_i64, sizeof(int32_t), "cutlass92_row_owner_local_expert"),
                  stream);
          const ReusableBufferAcquireResult row_owner_row =
              reusable_temp_buffers->row_owner_expert_row.ensure(
                  checked_bytes(total_slots_i64, sizeof(int32_t), "cutlass92_row_owner_expert_row"),
                  stream);
          execution_trace.row_owner_reused = row_owner_local.reused && row_owner_row.reused;
          execution_trace.row_owner_grew = row_owner_local.grew || row_owner_row.grew;
          if (temp_init.row_owner) {
            execution_trace.init_row_owner_family = true;
            zero_device_region(
                row_owner_local.ptr,
                row_owner_local.bytes,
                stream,
                "cudaMemsetAsync full init row_owner_local_expert");
            zero_device_region(
                row_owner_row.ptr,
                row_owner_row.bytes,
                stream,
                "cudaMemsetAsync full init row_owner_expert_row");
          }
          if (integrity_monitor.enabled()) {
            integrity_monitor.poison_region(
                row_owner_local.ptr,
                row_owner_local.bytes,
                "cudaMemsetAsync integrity row_owner_local_expert");
            integrity_monitor.poison_region(
                row_owner_row.ptr,
                row_owner_row.bytes,
                "cudaMemsetAsync integrity row_owner_expert_row");
          }
          if (use_short_cutlass92_path) {
            launch_short_cutlass92_metadata(
                topk_idx,
                topk_weight,
                counts_by_expert,
                starts_by_expert,
                offsets_by_expert,
                compact_slot_ids,
                slot_to_compact_row,
                compact_weights,
                total_local_slots,
                static_cast<int32_t*>(row_owner_local.ptr),
                static_cast<int32_t*>(row_owner_row.ptr),
                local_expert_offset,
                total_slots,
                stream);
          } else {
            build_cutlass92_row_owner_metadata_kernel<<<metadata_grid, kMetadataThreads, 0, stream>>>(
                counts_by_expert,
                starts_by_expert,
                static_cast<int32_t*>(row_owner_local.ptr),
                static_cast<int32_t*>(row_owner_row.ptr));
            check_launch("build_cutlass92_row_owner_metadata_kernel");
          }
          if (perturbation.sync_after_metadata) {
            check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize perturbation after metadata");
          }
          if (perturbation.metadata_hostcopy_sync) {
            cutlass92_trace.metadata_stage_ok = validate_cutlass92_metadata_contract(
                compact_slot_ids,
                static_cast<int32_t*>(row_owner_local.ptr),
                static_cast<int32_t*>(row_owner_row.ptr),
                counts_by_expert,
                starts_by_expert,
                offsets_by_expert,
                total_local_slots,
                total_slots,
                stream);
            if (!cutlass92_trace.metadata_stage_ok && std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
              cutlass92_trace.first_failed_stage = "metadata";
            }
          }

          Cutlass92Gemm1Result gemm1_result = try_cutlass92_gemm1(
              static_cast<const uint8_t*>(hidden_states.data_ptr()),
              static_cast<const float*>(hidden_states_scale.data_ptr()),
              compact_slot_ids,
              static_cast<int32_t*>(row_owner_local.ptr),
              static_cast<int32_t*>(row_owner_row.ptr),
              counts_by_expert,
              starts_by_expert,
              total_local_slots,
              static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
              static_cast<const float*>(gemm1_weights_scale.data_ptr()),
              seq_len_i32,
              total_slots,
              device.device_id,
              use_short_cutlass92_path,
              cutlass92_trace.stateless_diagnostic,
              temp_init.cutlass_launch,
              &integrity_monitor,
              stream);
          if (temp_init.cutlass_launch) {
            execution_trace.init_cutlass_launch_family = true;
          }
          cutlass92_trace.gemm1_ok = gemm1_result.ok;
          cutlass92_trace.retained_weight_state = gemm1_result.used_retained_weight_state;
          cutlass92_trace.retained_launch_state = gemm1_result.used_retained_launch_state;
          cutlass92_trace.schedule = gemm1_result.schedule;
          cutlass92_trace.n_cutlass = gemm1_result.counts.n_cutlass;
          cutlass92_trace.total_live_slots = gemm1_result.counts.total_live_slots;
          if (perturbation.sync_after_gemm1 && gemm1_result.ok) {
            check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize perturbation after gemm1");
          }
          if (perturbation.enabled) {
            if (!gemm1_result.ok && std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
              cutlass92_trace.first_failed_stage = "gemm1";
            } else if (perturbation.gemm1_reference_compare && gemm1_result.ok &&
                       std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
              const float gemm1_matched_ratio = cutlass92_compare_gemm1_output_matched_ratio(
                  static_cast<const uint8_t*>(hidden_states.data_ptr()),
                  static_cast<const float*>(hidden_states_scale.data_ptr()),
                  static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                  static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                  topk_idx,
                  compact_slot_ids,
                  total_local_slots,
                  reinterpret_cast<const __nv_bfloat16*>(gemm1_result.output->ptr),
                  local_expert_offset,
                  seq_len_i32,
                  total_slots,
                  stream);
              cutlass92_trace.gemm1_stage_ok = gemm1_matched_ratio >= kDebugCompareMinMatchedRatio;
              if (!cutlass92_trace.gemm1_stage_ok) {
                cutlass92_trace.first_failed_stage = "gemm1";
              }
            }
          }
          if (gemm1_result.ok && cutlass92_gemm2_active) {
            Cutlass92Gemm2Result gemm2_result = try_cutlass92_gemm2(
                reinterpret_cast<__nv_bfloat16*>(gemm1_result.output->ptr),
                static_cast<int32_t*>(row_owner_local.ptr),
                static_cast<int32_t*>(row_owner_row.ptr),
                counts_by_expert,
                starts_by_expert,
                total_local_slots,
                static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                gemm1_result.counts,
                gemm1_result.schedule,
                total_slots,
                device.device_id,
                use_short_cutlass92_path,
                cutlass92_trace.stateless_diagnostic,
                temp_init.cutlass_launch,
                &integrity_monitor,
                stream);
            cutlass92_trace.gemm2_ok = gemm2_result.ok;
            if (perturbation.enabled && !gemm2_result.ok &&
                std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
              cutlass92_trace.first_failed_stage = "gemm2";
            }
            if (gemm2_result.ok) {
              if (perturbation.sync_after_gemm2) {
                check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize perturbation after gemm2");
              }
              std::shared_ptr<CachedDeviceAllocation> gemm2_materialized_output;
              __nv_bfloat16* reduce_input = reinterpret_cast<__nv_bfloat16*>(gemm2_result.output->ptr);
              if (post_gemm2_materialization_diagnostic) {
                const size_t gemm2_output_bytes = checked_bytes(
                    static_cast<int64_t>(total_slots) * kHiddenSize,
                    sizeof(__nv_bfloat16),
                    "gemm2_materialized_output");
                gemm2_materialized_output = std::make_shared<CachedDeviceAllocation>(gemm2_output_bytes);
                check_cuda(
                    cudaMemcpyAsync(
                        gemm2_materialized_output->ptr,
                        gemm2_result.output->ptr,
                        gemm2_output_bytes,
                        cudaMemcpyDeviceToDevice,
                        stream),
                    "cudaMemcpyAsync post-GEMM2 materialization");
                reduce_input = reinterpret_cast<__nv_bfloat16*>(gemm2_materialized_output->ptr);
                cutlass92_trace.reduction_consumed_materialized_gemm2 = true;
              }
              const int32_t reduce_blocks = (total_output + kThreads - 1) / kThreads;
              if (use_fp32_finalization) {
                reduce_compact_output_fp32_kernel<<<reduce_blocks, kThreads, 0, stream>>>(
                    reduce_input,
                    slot_to_compact_row,
                    compact_weights,
                    total_local_slots,
                    output_fp32,
                    seq_len_i32);
                check_launch("reduce_compact_output_fp32_kernel");
                cast_output_kernel<<<reduce_blocks, kThreads, 0, stream>>>(
                    output_fp32,
                    static_cast<__nv_bfloat16*>(output.data_ptr()),
                    total_output);
                check_launch("cast_output_kernel fp32_finalization");
              } else {
                reduce_compact_output_bf16_kernel<<<reduce_blocks, kThreads, 0, stream>>>(
                    reduce_input,
                    slot_to_compact_row,
                    compact_weights,
                    total_local_slots,
                    static_cast<__nv_bfloat16*>(output.data_ptr()),
                    seq_len_i32);
                check_launch("reduce_compact_output_bf16_kernel");
              }
              maybe_compare_cutlass92_with_compact_fallback(
                  static_cast<const uint8_t*>(hidden_states.data_ptr()),
                  static_cast<const float*>(hidden_states_scale.data_ptr()),
                  static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                  static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                  static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                  static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                  topk_idx,
                  compact_slot_ids,
                  compact_weights,
                  total_local_slots,
                  gated,
                  output_fp32,
                  static_cast<const __nv_bfloat16*>(output.data_ptr()),
                  local_expert_offset,
                  seq_len_i32,
                  total_slots,
                  total_output,
                  stream);
              if ((!perturbation.gemm1_reference_compare || cutlass92_trace.gemm1_stage_ok) &&
                  std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
                if (gemm2_ref_components.enabled) {
                  if (gemm2_ref_components.prepare_reference) {
                    cutlass92_prepare_final_output_reference(
                        static_cast<const uint8_t*>(hidden_states.data_ptr()),
                        static_cast<const float*>(hidden_states_scale.data_ptr()),
                        static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                        static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                        static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                        static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                        topk_idx,
                        compact_slot_ids,
                        compact_weights,
                        total_local_slots,
                        gated,
                        output_fp32,
                        local_expert_offset,
                        seq_len_i32,
                        total_slots,
                        total_output,
                        prepare_reference_components.enabled ? &prepare_reference_components : nullptr,
                        stream);
                  }
                  if (gemm2_ref_components.compare_tail) {
                    const float gemm2_matched_ratio = cutlass92_compare_final_output_tail_matched_ratio(
                        output_fp32,
                        static_cast<const __nv_bfloat16*>(output.data_ptr()),
                        total_output,
                        stream);
                    cutlass92_trace.gemm2_stage_ok = gemm2_matched_ratio >= kDebugCompareMinMatchedRatio;
                    if (!cutlass92_trace.gemm2_stage_ok) {
                      cutlass92_trace.first_failed_stage = "gemm2";
                    }
                  }
                } else if (perturbation.gemm2_reference_compare) {
                  const float gemm2_matched_ratio = cutlass92_compare_final_output_matched_ratio(
                      static_cast<const uint8_t*>(hidden_states.data_ptr()),
                      static_cast<const float*>(hidden_states_scale.data_ptr()),
                      static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                      static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                      static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                      static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                      topk_idx,
                      compact_slot_ids,
                      compact_weights,
                      total_local_slots,
                      gated,
                      output_fp32,
                      static_cast<const __nv_bfloat16*>(output.data_ptr()),
                      local_expert_offset,
                      seq_len_i32,
                      total_slots,
                      total_output,
                      stream);
                  cutlass92_trace.gemm2_stage_ok = gemm2_matched_ratio >= kDebugCompareMinMatchedRatio;
                  if (!cutlass92_trace.gemm2_stage_ok) {
                    cutlass92_trace.first_failed_stage = "gemm2";
                  }
                }
              }
              maybe_log_cutlass92_trace(seq_len_i32, cutlass92_trace);
              final_path = "compact_cutlass92";
              cutlass_completed = true;
            }
          }
          if ((perturbation.metadata_hostcopy_sync || perturbation.gemm1_reference_compare ||
               perturbation.gemm2_reference_compare || gemm2_ref_components.compare_tail) &&
              std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0 &&
              (!perturbation.metadata_hostcopy_sync || cutlass92_trace.metadata_stage_ok) &&
              (!perturbation.gemm1_reference_compare || cutlass92_trace.gemm1_stage_ok) &&
              (!(perturbation.gemm2_reference_compare || gemm2_ref_components.compare_tail) ||
               cutlass92_trace.gemm2_stage_ok)) {
            cutlass92_trace.first_failed_stage = "passed";
          }
        }
        maybe_log_cutlass92_trace(seq_len_i32, cutlass92_trace);
#endif
      }

      if (!cutlass_completed) {
        if (use_short_cutlass92_path) {
          launch_short_compact_metadata(
              topk_idx,
              topk_weight,
              counts_by_expert,
              starts_by_expert,
              offsets_by_expert,
              compact_slot_ids,
              slot_to_compact_row,
              compact_weights,
              total_local_slots,
              local_expert_offset,
              total_slots,
              stream);
        }
        const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
        gemm1_swiglu_compact_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
            static_cast<const uint8_t*>(hidden_states.data_ptr()),
            static_cast<const float*>(hidden_states_scale.data_ptr()),
            static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
            static_cast<const float*>(gemm1_weights_scale.data_ptr()),
            topk_idx,
            compact_slot_ids,
            total_local_slots,
            gated,
            local_expert_offset,
            seq_len_i32,
            total_slots);
        check_launch("gemm1_swiglu_compact_kernel");

        const dim3 gemm2_grid(total_slots, (kHiddenSize + kThreads - 1) / kThreads);
        gemm2_compact_accumulate_kernel<<<gemm2_grid, kThreads, 0, stream>>>(
            static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
            static_cast<const float*>(gemm2_weights_scale.data_ptr()),
            topk_idx,
            compact_slot_ids,
            compact_weights,
            total_local_slots,
            gated,
            output_fp32,
            local_expert_offset,
            seq_len_i32,
            total_slots);
        check_launch("gemm2_compact_accumulate_kernel");
        final_path = "compact_fallback";
      }
    } else {
      const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
      gemm1_swiglu_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
          static_cast<const uint8_t*>(hidden_states.data_ptr()),
          static_cast<const float*>(hidden_states_scale.data_ptr()),
          static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
          static_cast<const float*>(gemm1_weights_scale.data_ptr()),
          topk_idx,
          gated,
          local_expert_offset,
          seq_len_i32,
          total_slots);
      check_launch("gemm1_swiglu_kernel");

      const dim3 gemm2_grid(total_slots, (kHiddenSize + kThreads - 1) / kThreads);
      gemm2_accumulate_kernel<<<gemm2_grid, kThreads, 0, stream>>>(
          static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
          static_cast<const float*>(gemm2_weights_scale.data_ptr()),
          topk_idx,
          topk_weight,
          gated,
          output_fp32,
          local_expert_offset,
          seq_len_i32,
          total_slots);
      check_launch("gemm2_accumulate_kernel");
      final_path = "dense_fallback";
    }

    const int32_t cast_blocks = (total_output + kThreads - 1) / kThreads;
    cast_output_kernel<<<cast_blocks, kThreads, 0, stream>>>(
        output_fp32,
        static_cast<__nv_bfloat16*>(output.data_ptr()),
        total_output);
    check_launch("cast_output_kernel");

    finalize_integrity(final_path);
    if (private_stream_diagnostic) {
      check_cuda(cudaEventRecord(private_stream_done_event.get(), stream), "cudaEventRecord private_stream_done");
      check_cuda(
          cudaStreamWaitEvent(caller_stream, private_stream_done_event.get(), 0),
          "cudaStreamWaitEvent caller waits on private stream");
    }
    if (device_fence_diagnostic) {
      check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize device fence post");
    }
    return;
  }

  maybe_log_execution_stream_trace(stream_trace_enabled, "start", execution_trace, "unassigned");
  integrity_monitor.log_start();

  CudaWorkspace workspace(workspace_bytes, stream, integrity_diagnostic);
  if (temp_init.workspace) {
    execution_trace.init_workspace_family = true;
    workspace.zero_all("cudaMemsetAsync full init workspace");
  }
  int32_t* topk_idx = workspace.alloc<int32_t>(total_slots_i64, "topk_idx");
  float* topk_weight = workspace.alloc<float>(total_slots_i64, "topk_weight");

  int32_t* counts_by_expert = nullptr;
  int32_t* slot_ids_by_expert = nullptr;
  float* weights_by_expert = nullptr;
  int32_t* slot_to_compact_row = nullptr;
  int32_t* starts_by_expert = nullptr;
  int32_t* offsets_by_expert = nullptr;
  int32_t* total_local_slots = nullptr;
  int32_t* compact_slot_ids = nullptr;
  float* compact_weights = nullptr;
  float* gated = nullptr;
  if (use_compact_workspace) {
    counts_by_expert = workspace.alloc<int32_t>(kNumLocalExperts, "counts_by_expert");
    slot_ids_by_expert =
        workspace.alloc<int32_t>(static_cast<int64_t>(kNumLocalExperts) * total_slots_i64, "slot_ids_by_expert");
    weights_by_expert =
        workspace.alloc<float>(static_cast<int64_t>(kNumLocalExperts) * total_slots_i64, "weights_by_expert");
    slot_to_compact_row = workspace.alloc<int32_t>(total_slots_i64, "slot_to_compact_row");
    starts_by_expert = workspace.alloc<int32_t>(kNumLocalExperts, "starts_by_expert");
    offsets_by_expert = workspace.alloc<int32_t>(kNumLocalExperts, "offsets_by_expert");
    total_local_slots = workspace.alloc<int32_t>(1, "total_local_slots");
    compact_slot_ids = workspace.alloc<int32_t>(total_slots_i64, "compact_slot_ids");
    compact_weights = workspace.alloc<float>(total_slots_i64, "compact_weights");
    gated = workspace.alloc<float>(total_slots_i64 * kIntermediateSize, "compact_gated");
  } else {
    gated = workspace.alloc<float>(total_slots_i64 * kIntermediateSize, "gated");
  }
  float* output_fp32 = workspace.alloc<float>(total_output_i64, "output_fp32");

  const size_t output_fp32_bytes = checked_bytes(total_output_i64, sizeof(float), "output_fp32");
  check_cuda(cudaMemsetAsync(output_fp32, 0, output_fp32_bytes, stream), "cudaMemsetAsync output_fp32");
  if (integrity_monitor.enabled()) {
    integrity_monitor.poison_region(output.data_ptr(), checked_bytes(total_output_i64, sizeof(__nv_bfloat16), "output"), "cudaMemsetAsync integrity output");
  }

  auto finalize_integrity = [&](const char* path) {
    maybe_log_execution_stream_trace(stream_trace_enabled, "end", execution_trace, path);
    if (!integrity_monitor.enabled()) {
      return;
    }
    integrity_monitor.set_path(path);
    integrity_monitor.synchronize_and_validate();
    workspace.validate_guards();
    integrity_monitor.log_end();
  };
  const char* final_path = use_compact_execution ? "compact_fallback" : "dense_fallback";
  bool cutlass_completed = false;
  const bool use_short_cutlass92_path = short_cutlass92_runtime_active;

  constexpr int32_t kThreads = 128;
  launch_route_topk(
      use_short_cutlass92_path,
      static_cast<const float*>(routing_logits.data_ptr()),
      static_cast<const __nv_bfloat16*>(routing_bias.data_ptr()),
      topk_idx,
      topk_weight,
      local_expert_offset,
      routed_scaling_factor,
      seq_len_i32,
      stream);

  if (use_short_seq_metadata_fastpath && !use_short_cutlass92_path) {
    launch_short_compact_metadata(
        topk_idx,
        topk_weight,
        counts_by_expert,
        starts_by_expert,
        offsets_by_expert,
        compact_slot_ids,
        slot_to_compact_row,
        compact_weights,
        total_local_slots,
        local_expert_offset,
        total_slots,
        stream);
  }

  if (use_compact_execution) {
    constexpr int32_t kMetadataThreads = 256;
    const dim3 metadata_grid((total_slots + kMetadataThreads - 1) / kMetadataThreads, kNumLocalExperts);
    if (use_compact_path || use_short_cutlass92_path) {
      check_cuda(
          cudaMemsetAsync(
              counts_by_expert,
              0,
              checked_bytes(kNumLocalExperts, sizeof(int32_t), "counts_by_expert"),
              stream),
          "cudaMemsetAsync counts_by_expert");

      const int32_t bin_blocks = (total_slots + kMetadataThreads - 1) / kMetadataThreads;
      build_local_expert_bins_kernel<<<bin_blocks, kMetadataThreads, 0, stream>>>(
          topk_idx,
          topk_weight,
          slot_ids_by_expert,
          weights_by_expert,
          counts_by_expert,
          slot_to_compact_row,
          local_expert_offset,
          total_slots);
      check_launch("build_local_expert_bins_kernel");

      build_expert_offsets_kernel<<<1, 1, 0, stream>>>(
          counts_by_expert,
          starts_by_expert,
          offsets_by_expert,
          total_local_slots);
      check_launch("build_expert_offsets_kernel");

      compact_expert_metadata_kernel<<<metadata_grid, kMetadataThreads, 0, stream>>>(
          slot_ids_by_expert,
          weights_by_expert,
          counts_by_expert,
          starts_by_expert,
          compact_slot_ids,
          slot_to_compact_row,
          compact_weights,
          total_slots);
      check_launch("compact_expert_metadata_kernel");
      maybe_validate_compact_metadata(
          topk_idx,
          compact_slot_ids,
          slot_to_compact_row,
          total_local_slots,
          local_expert_offset,
          total_slots,
          stream);

#if defined(LCR_ENABLE_CUTLASS92_TVM_FFI) && defined(CUTLASS_ARCH_MMA_SM100_SUPPORTED)
      Cutlass92InvocationTrace cutlass92_trace;
      cutlass92_trace.invocation_id = invocation_id;
      cutlass92_trace.runtime_enabled = cutlass_runtime_active;
      cutlass92_trace.fp32_finalization_active = use_fp32_finalization;
      cutlass92_trace.post_gemm2_materialization_active = post_gemm2_materialization_diagnostic;
      cutlass92_trace.gemm2_ref_component_bisection_active = gemm2_ref_components.enabled;
      cutlass92_trace.gemm2_ref_prepare_reference_active = gemm2_ref_components.prepare_reference;
      cutlass92_trace.gemm2_ref_compare_tail_active = gemm2_ref_components.compare_tail;
      cutlass92_trace.prepare_reference_component_bisection_active = prepare_reference_components.enabled;
      cutlass92_trace.prepare_reference_zero_output_active = prepare_reference_components.zero_output_fp32;
      cutlass92_trace.prepare_reference_gemm1_active = prepare_reference_components.fallback_gemm1_prepare;
      cutlass92_trace.prepare_reference_gemm2_accumulation_active =
          prepare_reference_components.fallback_gemm2_accumulation;
      cutlass92_trace.stateless_diagnostic = cutlass92_stateless_diagnostic_enabled();
      cutlass92_trace.full_temp_init_active = temp_init.enabled;
      cutlass92_trace.stage_validation_active = perturbation.full_stage_validation;
      cutlass92_trace.perturbation_bisection_active =
          perturbation.enabled && !perturbation.full_stage_validation;
      cutlass92_trace.private_stream_active = private_stream_diagnostic;
      cutlass92_trace.device_fence_active = device_fence_diagnostic;
      cutlass92_trace.caller_stream = reinterpret_cast<uintptr_t>(caller_stream);
      cutlass92_trace.execution_stream = reinterpret_cast<uintptr_t>(stream);
      if (cutlass92_trace.runtime_enabled) {
        cutlass92_trace.init_cutlass_launch_family = temp_init.cutlass_launch;
        cutlass92_trace.perturb_metadata_hostcopy_sync = perturbation.metadata_hostcopy_sync;
        cutlass92_trace.perturb_gemm1_reference_compare = perturbation.gemm1_reference_compare;
        cutlass92_trace.perturb_gemm2_reference_compare = perturbation.gemm2_reference_compare;
        cutlass92_trace.perturb_sync_after_metadata = perturbation.sync_after_metadata;
        cutlass92_trace.perturb_sync_after_gemm1 = perturbation.sync_after_gemm1;
        cutlass92_trace.perturb_sync_after_gemm2 = perturbation.sync_after_gemm2;
        DeviceBuffer row_owner_local_expert(
            checked_bytes(total_slots_i64, sizeof(int32_t), "cutlass92_row_owner_local_expert"),
            stream);
        DeviceBuffer row_owner_expert_row(
            checked_bytes(total_slots_i64, sizeof(int32_t), "cutlass92_row_owner_expert_row"),
            stream);
        if (temp_init.row_owner) {
          execution_trace.init_row_owner_family = true;
          zero_device_region(
              row_owner_local_expert.raw(),
              row_owner_local_expert.bytes(),
              stream,
              "cudaMemsetAsync full init row_owner_local_expert");
          zero_device_region(
              row_owner_expert_row.raw(),
              row_owner_expert_row.bytes(),
              stream,
              "cudaMemsetAsync full init row_owner_expert_row");
        }
        if (integrity_monitor.enabled()) {
          integrity_monitor.poison_region(
              row_owner_local_expert.raw(),
              row_owner_local_expert.bytes(),
              "cudaMemsetAsync integrity row_owner_local_expert");
          integrity_monitor.poison_region(
              row_owner_expert_row.raw(),
              row_owner_expert_row.bytes(),
              "cudaMemsetAsync integrity row_owner_expert_row");
        }
        if (use_short_cutlass92_path) {
          launch_short_cutlass92_metadata(
              topk_idx,
              topk_weight,
              counts_by_expert,
              starts_by_expert,
              offsets_by_expert,
              compact_slot_ids,
              slot_to_compact_row,
              compact_weights,
              total_local_slots,
              row_owner_local_expert.data<int32_t>(),
              row_owner_expert_row.data<int32_t>(),
              local_expert_offset,
              total_slots,
              stream);
        } else {
          build_cutlass92_row_owner_metadata_kernel<<<metadata_grid, kMetadataThreads, 0, stream>>>(
              counts_by_expert,
              starts_by_expert,
              row_owner_local_expert.data<int32_t>(),
              row_owner_expert_row.data<int32_t>());
          check_launch("build_cutlass92_row_owner_metadata_kernel");
        }
        if (perturbation.sync_after_metadata) {
          check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize perturbation after metadata");
        }
        if (perturbation.metadata_hostcopy_sync) {
          cutlass92_trace.metadata_stage_ok = validate_cutlass92_metadata_contract(
              compact_slot_ids,
              row_owner_local_expert.data<int32_t>(),
              row_owner_expert_row.data<int32_t>(),
              counts_by_expert,
              starts_by_expert,
              offsets_by_expert,
              total_local_slots,
              total_slots,
              stream);
          if (!cutlass92_trace.metadata_stage_ok && std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
            cutlass92_trace.first_failed_stage = "metadata";
          }
        }

        Cutlass92Gemm1Result gemm1_result = try_cutlass92_gemm1(
            static_cast<const uint8_t*>(hidden_states.data_ptr()),
            static_cast<const float*>(hidden_states_scale.data_ptr()),
            compact_slot_ids,
            row_owner_local_expert.data<int32_t>(),
            row_owner_expert_row.data<int32_t>(),
            counts_by_expert,
            starts_by_expert,
            total_local_slots,
            static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
            static_cast<const float*>(gemm1_weights_scale.data_ptr()),
            seq_len_i32,
            total_slots,
            device.device_id,
            use_short_cutlass92_path,
            cutlass92_trace.stateless_diagnostic,
            temp_init.cutlass_launch,
            &integrity_monitor,
            stream);
        if (temp_init.cutlass_launch) {
          execution_trace.init_cutlass_launch_family = true;
        }
        cutlass92_trace.gemm1_ok = gemm1_result.ok;
        cutlass92_trace.retained_weight_state = gemm1_result.used_retained_weight_state;
        cutlass92_trace.retained_launch_state = gemm1_result.used_retained_launch_state;
        cutlass92_trace.schedule = gemm1_result.schedule;
        cutlass92_trace.n_cutlass = gemm1_result.counts.n_cutlass;
        cutlass92_trace.total_live_slots = gemm1_result.counts.total_live_slots;
        if (perturbation.sync_after_gemm1 && gemm1_result.ok) {
          check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize perturbation after gemm1");
        }
        if (perturbation.enabled) {
          if (!gemm1_result.ok && std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
            cutlass92_trace.first_failed_stage = "gemm1";
          } else if (perturbation.gemm1_reference_compare && gemm1_result.ok &&
                     std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
            const float gemm1_matched_ratio = cutlass92_compare_gemm1_output_matched_ratio(
                static_cast<const uint8_t*>(hidden_states.data_ptr()),
                static_cast<const float*>(hidden_states_scale.data_ptr()),
                static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                topk_idx,
                compact_slot_ids,
                total_local_slots,
                reinterpret_cast<const __nv_bfloat16*>(gemm1_result.output->ptr),
                local_expert_offset,
                seq_len_i32,
                total_slots,
                stream);
            cutlass92_trace.gemm1_stage_ok = gemm1_matched_ratio >= kDebugCompareMinMatchedRatio;
            if (!cutlass92_trace.gemm1_stage_ok) {
              cutlass92_trace.first_failed_stage = "gemm1";
            }
          }
        }
        if (gemm1_result.ok && cutlass92_gemm2_active) {
          Cutlass92Gemm2Result gemm2_result = try_cutlass92_gemm2(
              reinterpret_cast<__nv_bfloat16*>(gemm1_result.output->ptr),
              row_owner_local_expert.data<int32_t>(),
              row_owner_expert_row.data<int32_t>(),
              counts_by_expert,
              starts_by_expert,
              total_local_slots,
              static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
              static_cast<const float*>(gemm2_weights_scale.data_ptr()),
              gemm1_result.counts,
              gemm1_result.schedule,
              total_slots,
              device.device_id,
              use_short_cutlass92_path,
              cutlass92_trace.stateless_diagnostic,
              temp_init.cutlass_launch,
              &integrity_monitor,
              stream);
          cutlass92_trace.gemm2_ok = gemm2_result.ok;
          if (perturbation.enabled && !gemm2_result.ok &&
              std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
            cutlass92_trace.first_failed_stage = "gemm2";
          }
          if (gemm2_result.ok) {
            if (perturbation.sync_after_gemm2) {
              check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize perturbation after gemm2");
            }
            std::shared_ptr<CachedDeviceAllocation> gemm2_materialized_output;
            __nv_bfloat16* reduce_input = reinterpret_cast<__nv_bfloat16*>(gemm2_result.output->ptr);
            if (post_gemm2_materialization_diagnostic) {
              const size_t gemm2_output_bytes = checked_bytes(
                  static_cast<int64_t>(total_slots) * kHiddenSize,
                  sizeof(__nv_bfloat16),
                  "gemm2_materialized_output");
              gemm2_materialized_output = std::make_shared<CachedDeviceAllocation>(gemm2_output_bytes);
              check_cuda(
                  cudaMemcpyAsync(
                      gemm2_materialized_output->ptr,
                      gemm2_result.output->ptr,
                      gemm2_output_bytes,
                      cudaMemcpyDeviceToDevice,
                      stream),
                  "cudaMemcpyAsync post-GEMM2 materialization");
              reduce_input = reinterpret_cast<__nv_bfloat16*>(gemm2_materialized_output->ptr);
              cutlass92_trace.reduction_consumed_materialized_gemm2 = true;
            }
            const int32_t reduce_blocks = (total_output + kThreads - 1) / kThreads;
            if (use_fp32_finalization) {
              reduce_compact_output_fp32_kernel<<<reduce_blocks, kThreads, 0, stream>>>(
                  reduce_input,
                  slot_to_compact_row,
                  compact_weights,
                  total_local_slots,
                  output_fp32,
                  seq_len_i32);
              check_launch("reduce_compact_output_fp32_kernel");
              cast_output_kernel<<<reduce_blocks, kThreads, 0, stream>>>(
                  output_fp32,
                  static_cast<__nv_bfloat16*>(output.data_ptr()),
                  total_output);
              check_launch("cast_output_kernel fp32_finalization");
            } else {
              reduce_compact_output_bf16_kernel<<<reduce_blocks, kThreads, 0, stream>>>(
                  reduce_input,
                  slot_to_compact_row,
                  compact_weights,
                  total_local_slots,
                  static_cast<__nv_bfloat16*>(output.data_ptr()),
                  seq_len_i32);
              check_launch("reduce_compact_output_bf16_kernel");
            }
            maybe_compare_cutlass92_with_compact_fallback(
                static_cast<const uint8_t*>(hidden_states.data_ptr()),
                static_cast<const float*>(hidden_states_scale.data_ptr()),
                static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                topk_idx,
                compact_slot_ids,
                compact_weights,
                total_local_slots,
                gated,
                output_fp32,
                static_cast<const __nv_bfloat16*>(output.data_ptr()),
                local_expert_offset,
                seq_len_i32,
                total_slots,
                total_output,
                stream);
            if ((!perturbation.gemm1_reference_compare || cutlass92_trace.gemm1_stage_ok) &&
                std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0) {
              if (gemm2_ref_components.enabled) {
                if (gemm2_ref_components.prepare_reference) {
                  cutlass92_prepare_final_output_reference(
                      static_cast<const uint8_t*>(hidden_states.data_ptr()),
                      static_cast<const float*>(hidden_states_scale.data_ptr()),
                      static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                      static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                      static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                      static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                      topk_idx,
                      compact_slot_ids,
                      compact_weights,
                      total_local_slots,
                      gated,
                      output_fp32,
                      local_expert_offset,
                      seq_len_i32,
                      total_slots,
                      total_output,
                      prepare_reference_components.enabled ? &prepare_reference_components : nullptr,
                      stream);
                }
                if (gemm2_ref_components.compare_tail) {
                  const float gemm2_matched_ratio = cutlass92_compare_final_output_tail_matched_ratio(
                      output_fp32,
                      static_cast<const __nv_bfloat16*>(output.data_ptr()),
                      total_output,
                      stream);
                  cutlass92_trace.gemm2_stage_ok = gemm2_matched_ratio >= kDebugCompareMinMatchedRatio;
                  if (!cutlass92_trace.gemm2_stage_ok) {
                    cutlass92_trace.first_failed_stage = "gemm2";
                  }
                }
              } else if (perturbation.gemm2_reference_compare) {
                const float gemm2_matched_ratio = cutlass92_compare_final_output_matched_ratio(
                    static_cast<const uint8_t*>(hidden_states.data_ptr()),
                    static_cast<const float*>(hidden_states_scale.data_ptr()),
                    static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
                    static_cast<const float*>(gemm1_weights_scale.data_ptr()),
                    static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
                    static_cast<const float*>(gemm2_weights_scale.data_ptr()),
                    topk_idx,
                    compact_slot_ids,
                    compact_weights,
                    total_local_slots,
                    gated,
                    output_fp32,
                    static_cast<const __nv_bfloat16*>(output.data_ptr()),
                    local_expert_offset,
                    seq_len_i32,
                    total_slots,
                    total_output,
                    stream);
                cutlass92_trace.gemm2_stage_ok = gemm2_matched_ratio >= kDebugCompareMinMatchedRatio;
                if (!cutlass92_trace.gemm2_stage_ok) {
                  cutlass92_trace.first_failed_stage = "gemm2";
                }
              }
            }
            maybe_log_cutlass92_trace(seq_len_i32, cutlass92_trace);
            final_path = "compact_cutlass92";
            cutlass_completed = true;
          }
        }
        if ((perturbation.metadata_hostcopy_sync || perturbation.gemm1_reference_compare ||
             perturbation.gemm2_reference_compare || gemm2_ref_components.compare_tail) &&
            std::strcmp(cutlass92_trace.first_failed_stage, "not_run") == 0 &&
            (!perturbation.metadata_hostcopy_sync || cutlass92_trace.metadata_stage_ok) &&
            (!perturbation.gemm1_reference_compare || cutlass92_trace.gemm1_stage_ok) &&
            (!(perturbation.gemm2_reference_compare || gemm2_ref_components.compare_tail) ||
             cutlass92_trace.gemm2_stage_ok)) {
          cutlass92_trace.first_failed_stage = "passed";
        }
      }
      maybe_log_cutlass92_trace(seq_len_i32, cutlass92_trace);
#endif
    }

    if (!cutlass_completed) {
      if (use_short_cutlass92_path) {
        launch_short_compact_metadata(
            topk_idx,
            topk_weight,
            counts_by_expert,
            starts_by_expert,
            offsets_by_expert,
            compact_slot_ids,
            slot_to_compact_row,
            compact_weights,
            total_local_slots,
            local_expert_offset,
            total_slots,
            stream);
      }
      const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
      gemm1_swiglu_compact_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
          static_cast<const uint8_t*>(hidden_states.data_ptr()),
          static_cast<const float*>(hidden_states_scale.data_ptr()),
          static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
          static_cast<const float*>(gemm1_weights_scale.data_ptr()),
          topk_idx,
          compact_slot_ids,
          total_local_slots,
          gated,
          local_expert_offset,
          seq_len_i32,
          total_slots);
      check_launch("gemm1_swiglu_compact_kernel");

      const dim3 gemm2_grid(total_slots, (kHiddenSize + kThreads - 1) / kThreads);
      gemm2_compact_accumulate_kernel<<<gemm2_grid, kThreads, 0, stream>>>(
          static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
          static_cast<const float*>(gemm2_weights_scale.data_ptr()),
          topk_idx,
          compact_slot_ids,
          compact_weights,
          total_local_slots,
          gated,
          output_fp32,
          local_expert_offset,
          seq_len_i32,
          total_slots);
      check_launch("gemm2_compact_accumulate_kernel");
      final_path = "compact_fallback";
    }
  } else {
    const dim3 gemm1_grid(total_slots, (kIntermediateSize + kThreads - 1) / kThreads);
    gemm1_swiglu_kernel<<<gemm1_grid, kThreads, 0, stream>>>(
        static_cast<const uint8_t*>(hidden_states.data_ptr()),
        static_cast<const float*>(hidden_states_scale.data_ptr()),
        static_cast<const uint8_t*>(gemm1_weights.data_ptr()),
        static_cast<const float*>(gemm1_weights_scale.data_ptr()),
        topk_idx,
        gated,
        local_expert_offset,
        seq_len_i32,
        total_slots);
    check_launch("gemm1_swiglu_kernel");

    const dim3 gemm2_grid(total_slots, (kHiddenSize + kThreads - 1) / kThreads);
    gemm2_accumulate_kernel<<<gemm2_grid, kThreads, 0, stream>>>(
        static_cast<const uint8_t*>(gemm2_weights.data_ptr()),
        static_cast<const float*>(gemm2_weights_scale.data_ptr()),
        topk_idx,
        topk_weight,
        gated,
        output_fp32,
        local_expert_offset,
        seq_len_i32,
        total_slots);
    check_launch("gemm2_accumulate_kernel");
    final_path = "dense_fallback";
  }

  if (!cutlass_completed) {
    const int32_t cast_blocks = (total_output + kThreads - 1) / kThreads;
    cast_output_kernel<<<cast_blocks, kThreads, 0, stream>>>(
        output_fp32,
        static_cast<__nv_bfloat16*>(output.data_ptr()),
        total_output);
    check_launch("cast_output_kernel");
  }
  finalize_integrity(final_path);
  if (private_stream_diagnostic) {
    check_cuda(cudaEventRecord(private_stream_done_event.get(), stream), "cudaEventRecord private_stream_done");
    check_cuda(
        cudaStreamWaitEvent(caller_stream, private_stream_done_event.get(), 0),
        "cudaStreamWaitEvent caller waits on private");
  }
  if (device_fence_diagnostic) {
    check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize device fence post");
  }
}

}  // namespace moe_tvm_ffi

TVM_FFI_DLL_EXPORT_TYPED_FUNC(kernel, moe_tvm_ffi::Kernel);
