#pragma once

namespace moe_base {
namespace baseline {

constexpr int kNumExperts = 256;
constexpr int kNumLocalExperts = 32;
constexpr int kHiddenSize = 7168;
constexpr int kIntermediateSize = 2048;
constexpr int kGemm1OutSize = 4096;
constexpr int kBlockSize = 128;
constexpr int kNumHiddenBlocks = 56;
constexpr int kNumIntermediateBlocks = 16;
constexpr int kNumGemm1OutBlocks = 32;
constexpr int kTopK = 8;
constexpr int kNumGroups = 8;
constexpr int kTopKGroups = 4;
constexpr int kExpertsPerGroup = kNumExperts / kNumGroups;
constexpr int kBfloat16Bytes = 2;

constexpr int kRoutingMethodDeepSeekV3 = 2;
constexpr bool kUseShuffledWeight = false;

// Source references for this source-packed TVM-FFI adaptation:
// - extern/orphan/mlsys26-contest/solutions/baseline/moe/.../flashinfer_wrapper_9sdjf3.json
// - extern/orphan/flashinfer/csrc/fused_moe/noAuxTcKernels.cu
// - extern/orphan/flashinfer/csrc/fused_moe/trtllm_backend/
// - extern/orphan/flashinfer/csrc/trtllm_fused_moe_kernel_launcher.cu
// - extern/orphan/flashinfer/csrc/trtllm_fused_moe_runner.cu
// - extern/orphan/cutlass/examples/81_blackwell_gemm_blockwise/
// - extern/orphan/cutlass/examples/92_blackwell_moe_gemm/

}  // namespace baseline
}  // namespace moe_base
