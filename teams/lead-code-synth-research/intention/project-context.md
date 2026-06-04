# Project Context: lead-code-synth-research

## Detected Project

- Project root detected with Git: `/data/ssd1/huangzhe/code/hmdemo-mlsys26-contest`.
- Repository identity: `hmdemo-mlsys26-contest`, a Pixi-managed Python starter kit and Houmao demo fork for the MLSys 2026 FlashInfer AI Kernel Generation Contest.
- The repo supports CUDA/Triton contest solution work, local and Modal benchmarking, variant management, OpenSpec tracking, and project-local CUDA optimization skills.

## Tools And Commands

- Package and task runner: Pixi configuration in `pyproject.toml` under `[tool.pixi]`; no separate `pixi.toml` was present.
- Common checks: `pixi run test`, `pixi run lint`, `pixi run typecheck`, and `pixi run pack`.
- Benchmark commands: `pixi run bench` requires a CUDA-capable local environment and `FIB_DATASET_PATH`; `pixi run modal-bench` requires Modal setup.
- CUDA 13 / Blackwell helper environment: `pixi run -e cu130 nvcc --version`; this environment sets CUDA 13 paths and `TORCH_CUDA_ARCH_LIST=10.0a`.
- Repo management CLI: `pixi run project-cli variant list`, `pixi run project-cli variant status`, `pixi run project-cli workload source list`, and related `project-cli` commands.

## Contracts And Surfaces

- Configured contest solution in `config.toml`: CUDA build, TVM-FFI binding, destination passing enabled, entry point `kernel.cu::kernel`.
- Active definition in `config.toml`: `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- Primary implementation surfaces: `solution/cuda/kernel.cu`, `solution/cuda/binding.py`, and `solution/triton/kernel.py`.
- Pack and benchmark helpers live under `scripts/`; importable project code and `project-cli` live under `src/hmdemo_mlsys26_contest/`.
- Contest and profiling docs include `docs/contest/kernel-contracts.md` and `docs/profiling/cpp-nvbench-profiler.md`.
- CUTLASS/CuTe headers are available through `thirdparty/cutlass/include` and are listed in `config.toml` as `dev_include_roots`; ignored `extern/orphan/` checkouts are reference material, not submission dependencies.
- OpenSpec accepted specs live under `openspec/specs/`; non-trivial project behavior changes should use the repo OpenSpec workflow before implementation.

## Domain Notes

- The contest targets high-performance GPU kernels for LLM operations on NVIDIA Blackwell GPUs.
- The README lists tracks for fused MoE, sparse attention, and gated delta net; this repo is currently configured for a fused MoE FP8 block-scale definition.
- Default unit and integration checks should avoid GPU or dataset dependency; GPU and dataset dependent timing belongs in explicit benchmark paths.
- Generated `solution.json`, `.pixi/`, `tmp/`, and ignored external checkouts should not be committed.
- This loop root contains `source/mlsys26-tech-report.pdf`, which is the design seed for the intended Houmao multi-agent optimization loop.
- Accepted first implementation scope: active Fused MoE only, using `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.

## Open Questions

- UNRESOLVED - Live gateway/mail routing, local GPU access, Modal access, and offline-only versus executable loop posture still need decisions.
