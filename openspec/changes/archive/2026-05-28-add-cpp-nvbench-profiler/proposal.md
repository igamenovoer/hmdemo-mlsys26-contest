## Why

Kernel iteration needs a fast local timing path that can measure a solution kernel against different contest workloads without running the full FlashInfer-Bench correctness and reference-baseline pipeline. A C++ NVBench-based profiler gives developers stable timing, NVBench output formats, and workload sweeps while keeping official FlashInfer-Bench evaluation unchanged.

## What Changes

- Add a Conan-compatible C++ project under `cpp/` for an NVBench profiling tool.
- Introduce a build/run split: `build` compiles a reusable profiler artifact for a kernel, definition adapter, compiler configuration, and include-root set; `run` reuses that artifact for one or more workloads without recompiling.
- Support an initial MoE TVM-FFI adapter for kernels matching `kernel.cu::kernel` and the contest MoE destination-passing signature.
- Load FlashInfer Trace-style local definition/workload data in C++ for profiling input materialization, including safetensors inputs, random tensors, scalar inputs, and output allocation.
- Time only the solution kernel through NVBench; do not compute FlashInfer reference outputs or perform correctness checks in the profiling hot path.
- Provide CLI options aligned with the performance-related FlashInfer-Bench knobs where meaningful, and map them to NVBench measurement controls and output formats.
- Keep the profiler as local development tooling, not part of submission packing or default unit-test paths.

## Capabilities

### New Capabilities

- `cpp-nvbench-profiler`: Defines the C++ NVBench profiler workflow, artifact build/run separation, workload materialization, timing behavior, CLI compatibility, and project layout expectations.

### Modified Capabilities

None.

## Impact

- Adds a new `cpp/` tree with Conan/CMake project metadata, C++/CUDA sources, adapters, templates, and tests or smoke checks.
- May add Pixi tasks or documentation for building and running the C++ profiler, while preserving existing `pixi run bench`, `pixi run pack`, and project variant behavior.
- Uses NVBench from `extern/orphan/nvbench` initially as local development reference/source, CUDA Toolkit headers/libraries from the CUDA environment, and TVM-FFI headers/libraries for TVM-FFI adapter support.
- Uses C++ dependencies such as CLI parsing and JSON parsing through Conan-compatible project metadata.
- Reads local contest workload data but does not replace FlashInfer-Bench correctness-gated evaluation.
