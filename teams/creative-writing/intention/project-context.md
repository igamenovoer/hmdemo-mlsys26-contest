# Project Context: creative-writing

## Detected Project

- Project root: `/data/ssd1/huangzhe/code/hmdemo-mlsys26-contest`.
- Repository identity: Pixi-managed Python 3.12 starter kit and Houmao demo fork for the MLSys 2026 FlashInfer AI Kernel Generation Contest.
- Contest focus: generate, pack, benchmark, and iterate CUDA or Triton kernels for FlashInfer-Bench workloads on NVIDIA Blackwell GPUs.

## Tools And Commands

- Package and task manager: Pixi via `[tool.pixi.*]` in `pyproject.toml`; no standalone `pixi.toml` was found at the repository root.
- Common checks: `pixi run test`, `pixi run lint`, `pixi run typecheck`, and `pixi run pack`.
- CUDA 13 / Blackwell environment: `pixi run -e cu130 nvcc --version`; the `cu130` Pixi environment sets CUDA 13.0 paths and `TORCH_CUDA_ARCH_LIST=10.0a`.
- Benchmark entrypoints: `pixi run bench` requires a local CUDA-capable environment and `FIB_DATASET_PATH`; `pixi run modal-bench` requires Modal setup.
- Project CLI: `pixi run project-cli variant list`, `pixi run project-cli variant status`, `pixi run project-cli workload source list`, and related variant/workload commands.

## Contracts And Surfaces

- Live contest config: `config.toml` uses CUDA with TVM-FFI binding, destination passing enabled, and entry point `solution/cuda/kernel.cu::kernel`.
- Current definition: `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- Source surfaces: `solution/cuda/`, `solution/triton/`, `scripts/`, `src/hmdemo_mlsys26_contest/`, `tests/`, `docs/`, `context/`, `skillset/`, `variants/`, and `configs/`.
- Documentation: `docs/README.md`, `docs/contest/kernel-contracts.md`, and `docs/profiling/cpp-nvbench-profiler.md` describe project commands, kernel contracts, and local timing workflows.
- Variant workflow: CUDA variants live under `variants/cuda/` and are tracked in `configs/variants.toml`; `project-cli variant deploy/stock/diff` manages the live `solution/cuda/` bundle.
- OpenSpec convention: non-trivial behavior, workflow, or project-convention changes should use OpenSpec artifacts under `openspec/changes/` before implementation.

## Domain Notes

- Preserve the starter-kit shape expected by the contest evaluator.
- Do not commit generated `solution.json`, `.pixi/`, `tmp/`, or files under `extern/orphan/`.
- Keep GPU- or dataset-dependent checks out of the default unit-test path.
- CUTLASS/CuTe headers used by the solution are available under `thirdparty/cutlass/include`; ignored local checkouts under `extern/orphan/` are reference material, not submission dependencies.
- The repository has project-local CUDA optimization skills and runtime operation skills, but this init step does not generate `execplan/` material or launch agents.

## Open Questions

- UNRESOLVED - The creative-writing loop objective, participants, operating model, and acceptance criteria were not provided during init.
