## ADDED Requirements

### Requirement: MoE Base Matches FlashInfer Baseline Contract
The `moe-base` CUDA variant SHALL implement the contest MoE definition `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048` through the TVM-FFI destination-passing signature documented for the repository.

#### Scenario: Evaluator calls TVM-FFI MoE entry point
- **WHEN** the evaluator invokes `kernel.cu::kernel` for the MoE definition
- **THEN** the callable accepts the ten MoE inputs in definition order, accepts `local_expert_offset` as `int64_t`, accepts `routed_scaling_factor` as `double`, and writes the bfloat16 result into the destination-passed `output` tensor

### Requirement: Baseline Constants And Layouts Are Preserved
The `moe-base` implementation SHALL preserve the FlashInfer baseline constants and layout assumptions: 256 global experts, top-k 8, 8 groups, 4 selected groups, hidden size 7168, intermediate size 2048, 128-element scale blocks, MajorK expert weights, DeepSeekV3 routing mode, unshuffled weights, Swiglu activation, FP8 E4M3 operands, FP32 block scales, and bfloat16 output.

#### Scenario: Kernel validates fixed MoE geometry
- **WHEN** `moe-base` is built for the named MoE definition
- **THEN** the implementation uses the fixed geometry and baseline mode constants instead of a generic or coarse `fused_moe` interface

### Requirement: DeepSeekV3 Routing Semantics Are Followed
The `moe-base` implementation SHALL follow the FlashInfer DeepSeekV3 routing semantics where biased sigmoid scores select expert groups and experts, while the final routed weights are normalized from the unbiased sigmoid scores and multiplied by `routed_scaling_factor`.

#### Scenario: Local expert receives routed token
- **WHEN** a token selects an expert in the local expert range
- **THEN** the implementation includes that token-expert pair in the local work and uses the normalized routed weight for final accumulation

#### Scenario: Selected expert is not local
- **WHEN** a token selects an expert outside the local expert range
- **THEN** the implementation excludes that expert contribution from the local GEMM work

### Requirement: Real MoE Arithmetic Runs During Timing
The `moe-base` official validation path SHALL execute real routing, GEMM, activation, and finalize arithmetic during timed benchmark iterations.

#### Scenario: Official timing is run
- **WHEN** the official local evaluation method runs correctness-gated timing for `moe-base`
- **THEN** output-cache replay or placeholder output generation is disabled or absent from the benchmarked path

### Requirement: Source-Packable Dependencies Only
The `moe-base` packed solution SHALL build from its packed sources and permitted header-only CUDA/CUTLASS/CuTe dependencies without runtime dependence on installed FlashInfer Python, FlashInfer cubin packages, FlashInfer JIT downloads, local `extern/orphan/` paths, CMake install prefixes, or runtime `CPATH`.

#### Scenario: Solution is packed for evaluation
- **WHEN** `pixi run pack` creates `solution.json`
- **THEN** all source files and required source-packable headers used by `moe-base` are included intentionally or are supplied by the CUDA Toolkit/build environment

### Requirement: CUTLASS GEMM Adapter Is Stage-Compatible
The `moe-base` GEMM stages SHALL use a source-packable CUDA/CUTLASS/CuTe adapter that is compatible with the staged MoE dataflow and the contest FP8 block-scale tensor layouts.

#### Scenario: GEMM1 executes
- **WHEN** local expert rows have been compacted for GEMM1
- **THEN** the GEMM adapter computes the equivalent of `[local_rows, 7168] x [7168, 4096]` with the contest hidden-state and GEMM1 weight scales

#### Scenario: GEMM2 executes
- **WHEN** Swiglu activation has produced local expert intermediate rows
- **THEN** the GEMM adapter computes the equivalent of `[local_rows, 2048] x [2048, 7168]` with the contest GEMM2 weight scales

### Requirement: Official Evaluation Uses Idle GPUs
The development workflow SHALL run GPU-dependent official evaluation only on idle GPUs with enough available VRAM and near-idle SM utilization.

#### Scenario: No suitable GPU is idle
- **WHEN** no GPU satisfies the idle and memory requirements for the MoE benchmark
- **THEN** the workflow waits instead of running evaluation on a busy GPU
