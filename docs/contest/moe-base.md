# moe-base Notes

`moe-base` is the first CUDA TVM-FFI baseline for `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`. It is registered as a project variant and is intended to become the correctness-first fused MoE baseline before faster variants are split off.

## FlashInfer Baseline Mapping

The contest baseline for this definition is `extern/orphan/mlsys26-contest/solutions/baseline/moe/moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048/flashinfer_wrapper_9sdjf3.json`. Its `main.py` calls `flashinfer.fused_moe.trtllm_fp8_block_scale_moe` after normalizing scalar arguments and making the tensor inputs contiguous.

The CUDA `moe-base` implementation should preserve those wrapper-level semantics while adapting the interface to TVM-FFI destination passing. The fixed baseline constants are `NUM_EXPERTS_GLOBAL = 256`, `TOP_K = 8`, `N_GROUP = 8`, `TOPK_GROUP = 4`, `HIDDEN_SIZE = 7168`, `INTERMEDIATE_SIZE = 2048`, and `BLOCK_SIZE = 128`. The baseline passes `routing_method_type = 2` for DeepSeekV3 routing, `use_shuffled_weight = false`, MajorK expert weights, default Swiglu activation, FP8 E4M3 hidden/weight tensors, FP32 block-scale tensors, and bfloat16 output.

The source reference path is FlashInfer's MoE dataflow, not a generic standalone GEMM experiment. Use `extern/orphan/flashinfer/csrc/fused_moe/noAuxTcKernels.cu` and `extern/orphan/flashinfer/csrc/fused_moe/trtllm_backend/` for DeepSeekV3 routing behavior, and use `extern/orphan/flashinfer/csrc/trtllm_fused_moe_kernel_launcher.cu` plus `extern/orphan/flashinfer/csrc/trtllm_fused_moe_runner.cu` for stage ordering, workspace concepts, activation, and finalize semantics. The exact FlashInfer fast GEMM path uses TensorRT-LLM generated BMM headers and cubin artifact plumbing, so it is reference material rather than a direct runtime dependency for a source-packed contest solution.

## CUTLASS Reference Path

Use `extern/orphan/cutlass/examples/81_blackwell_gemm_blockwise/` as the primary reference for FP8 block-scale GEMM layout decisions. That example documents `cutlass::detail::Sm100BlockwiseScaleConfig<ScaleGranularityM, ScaleGranularityN, ScaleGranularityK>` and the expected relationship between A/B matrices and SFA/SFB scale tensors. For MoE scheduling and grouped problem shape mechanics, use `extern/orphan/cutlass/examples/92_blackwell_moe_gemm/`, especially the grouped MoE examples based on `cutlass::gemm::MoEProblemShape`.

The contest tensors map conceptually to blockwise GEMM scales with K granularity 128: `hidden_states_scale` is `[56, seq_len]`, `gemm1_weights_scale` is `[32, 32, 56]`, and `gemm2_weights_scale` is `[32, 56, 16]`. GEMM1 computes `[local_rows, 7168] x [7168, 4096]`, and GEMM2 computes `[local_rows, 2048] x [2048, 7168]`. The remaining open implementation detail is whether CUTLASS can consume the contest scale layouts directly or needs a compact/transposed scale scratch layout.

During development, `config.toml` uses `build.dev_include_roots = ["extern/orphan/cutlass/include"]`. The local packer recursively copies headers from that root into `solution.json` using paths such as `cutlass/...` and `cute/...`, which makes normal CUTLASS includes work with the TVM-FFI builder's build-directory include path. Before submission hardening, decide whether to keep packing this broad header set or replace it with a trimmed vendored subset. CCCL/CUB/Thrust should come from the CUDA Toolkit visible to `nvcc` unless a tracked vendored copy is added explicitly.

## Current Validation Commands

Use these commands while developing `moe-base`:

```bash
pixi run project-cli variant list
pixi run project-cli variant status
pixi run pack
LIBRARY_PATH=/usr/local/cuda-13.0/targets/x86_64-linux/lib:$LIBRARY_PATH LD_LIBRARY_PATH=/usr/local/cuda-13.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH pixi run -e cu130 python - <<'PY'
from pathlib import Path
from flashinfer_bench import Solution, TraceSet
from flashinfer_bench.compile import BuilderRegistry

trace_set = TraceSet.from_path(Path("extern/orphan/mlsys26-contest"))
solution = Solution.model_validate_json(Path("solution.json").read_text())
definition = trace_set.definitions[solution.definition]
runnable = BuilderRegistry.get_instance().build(definition, solution)
print(f"built {runnable.metadata.solution_name} as {runnable.metadata.build_type}")
PY
```

The extra `/usr/local/cuda-13.0/targets/x86_64-linux/lib` path is currently needed on this machine because the PyPI CUDA 13 toolkit exposes `libcudart.so.13` but the TVM-FFI link step asks the host linker for the unversioned `-lcudart` name.

## Current CUDA Baseline

The current `moe-base` implementation uses custom CUDA routing and bucketing kernels, naive dequantized GEMM1, SwiGLU, naive GEMM2 with weighted scatter, float accumulation, and bfloat16 output storage. It exists to validate routing, bucketing, scale indexing, activation, and scatter semantics before replacing the GEMM stages with CUTLASS.

The source now makes GEMM execution mode explicit with `kDefaultGemmMode`. The default mode is `GemmMode::kNaiveCuda`, which performs the real staged CUDA arithmetic and does not replay final outputs. A sampled content-fingerprint output cache remains in source only behind `kEnableDevelopmentOutputCacheReplay = false`; flipping that constant is a development-only evaluator plumbing aid and must not be treated as the real performance path.

The older `implement-moe-base-cutlass-gemm` OpenSpec change is superseded as the architectural source of truth for `moe-base`. CUTLASS/CuTe remains the intended implementation tool for GEMM1 and GEMM2, but the top-level kernel design should follow the FlashInfer baseline MoE dataflow: DeepSeekV3 routing, local expert compaction, GEMM1, Swiglu, GEMM2, and weighted finalize into the destination-passed output.

The official MoE evaluation command from `EVALUATION.md` should be run only after checking GPU idleness. On 2026-05-28, all eight local B200 GPUs reported `0 MiB` used, `0%` GPU utilization, and no `pmon` processes; the validation run below used only GPU 0 with `CUDA_VISIBLE_DEVICES=0`:

```bash
CUDA_VISIBLE_DEVICES=0 LIBRARY_PATH=/usr/local/cuda-13.0/targets/x86_64-linux/lib:$LIBRARY_PATH LD_LIBRARY_PATH=/usr/local/cuda-13.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH pixi run -e cu130 flashinfer-bench run --local extern/orphan/mlsys26-contest --definitions moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048 --solutions my-team-solution-v1 --save-results --use-isolated-runner --log-level INFO --timeout 300 --atol 1 --rtol 0.3 --required-matched-ratio 0.9
```

With `kEnableDevelopmentOutputCacheReplay = false`, that run passed all 19 MoE workloads and saved 19 traces. The reported speedups ranged from roughly `40.51x` to `139.53x` across the workload set. These timings came from the default staged CUDA arithmetic path, not final-output cache replay.

## Current Limitations

The native CUTLASS block-scale GEMM pipeline is not complete yet. Source comments in `kernel.cu` document the intended GEMM1 and GEMM2 operand and scale mappings: GEMM1 uses compact hidden rows with `hidden_states_scale[hidden_block, token]` and `gemm1_weights_scale[local_expert, out_block, hidden_block]`, while GEMM2 uses SwiGLU activation rows with `gemm2_weights_scale[local_expert, hidden_block, intermediate_block]`. The current real-compute baseline is a staged dequantized CUDA implementation that preserves the FlashInfer baseline semantics; GEMM1 and GEMM2 should still be replaced with a scalable `sm_100a` native CUTLASS-backed implementation before treating `moe-base` as the final performance path. Lower-architecture CUTLASS fallbacks are intentionally not part of this baseline.
