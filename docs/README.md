# Project Documentation

This repository is a Pixi-managed Python starter kit for the MLSys 2026 FlashInfer AI Kernel Generation Contest. It includes pack and benchmark helpers, CUDA and Triton solution bundles, project-local variant management, OpenSpec change tracking, and CUDA kernel optimization skill material for agents.

## Current CUDA Solution

The live CUDA solution is configured for the contest MoE definition `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`. The configured entry point is `solution/cuda/kernel.cu::kernel` with TVM-FFI destination passing enabled. The current `moe-base` variant is a correctness-first CUDA baseline that uses explicit CUDA kernels for routing, local-slot compaction, FP8 dequantization, SwiGLU, weighted accumulation, and BF16 output conversion, with basic CUTLASS GEMM calls for GEMM1 and GEMM2.

CUTLASS/CuTe headers used by the solution live under `thirdparty/cutlass/include` and are packed through `config.toml` via `dev_include_roots`. Local ignored checkouts under `extern/orphan/` are reference material and dataset/tooling sources, not submission dependencies.

## Common Commands

```bash
pixi run test
pixi run lint
pixi run typecheck
pixi run pack
pixi run project-cli variant list
pixi run project-cli variant status
pixi run project-cli workload source list
pixi run -e cu130 nvcc --version
```

Use `pixi run bench` for official local FlashInfer-Bench evaluation when a CUDA-capable environment and `FIB_DATASET_PATH` are available. Use `pixi run modal-bench` when Modal is configured.

## Variant Workflow

CUDA variants live under `variants/cuda/` and are tracked in `configs/variants.toml`. The repository currently includes `moe-base`, which can be deployed or restocked with:

```bash
pixi run project-cli variant deploy moe-base
pixi run project-cli variant stock moe-base
pixi run project-cli variant diff moe-base
```

The live `config.toml` must match a variant's definition and TVM-FFI build metadata before `project-cli variant deploy` will overwrite `solution/cuda/`.

## Documentation Map

- `contest/kernel-contracts.md`: TVM-FFI callable contracts for the local MoE and DSA contest definitions, including tensor order, scalar boundary types, and output order.
- `profiling/cpp-nvbench-profiler.md`: Local timing-only C++/NVBench profiler workflow for building reusable kernel plugins and running selected workloads.

## OpenSpec State

Accepted project behavior is tracked under `openspec/specs/`. Completed changes are archived under `openspec/changes/archive/`. Run `openspec list --specs` to inspect the accepted capabilities and `openspec validate <spec-or-change>` before committing spec updates.
