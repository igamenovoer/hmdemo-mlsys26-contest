## 1. C++ Project Scaffold

- [x] 1.1 Create `cpp/` with Conan-compatible project metadata, top-level CMake configuration, source/include directories, adapter directories, runner directories, and test or smoke-check directories.
- [x] 1.2 Declare C++ dependencies for CLI parsing, JSON parsing, and formatting through the C++ project metadata.
- [x] 1.3 Add CMake options for CUDA architecture, NVBench source path, TVM-FFI root, CUTLASS include roots, artifact output root, and build type.
- [x] 1.4 Add documentation or wrapper notes showing how to configure the project in the CUDA 13 Pixi environment.

## 2. Artifact Build Model

- [x] 2.1 Define an artifact manifest schema that records build-input metadata and excludes workload/runtime-only inputs.
- [x] 2.2 Implement build-input hashing for kernel source content, adapter, definition identity, compiler options, CUDA architecture, include roots, NVBench metadata, TVM-FFI metadata, and profiler version.
- [x] 2.3 Implement the profiler `build` command that creates or refreshes an artifact directory and writes the manifest.
- [x] 2.4 Configure CMake generation/build of a reusable NVBench runner artifact for the selected kernel and adapter.
- [x] 2.5 Detect stale artifacts when kernel source or other build inputs change and report whether rebuild is required.

## 3. Runtime Workload Loading

- [x] 3.1 Implement C++ loading for local FlashInfer Trace-style definition JSON and workload JSONL files.
- [x] 3.2 Implement workload selector resolution by exact UUID and unique UUID prefix, including ambiguous-prefix errors.
- [x] 3.3 Implement named workload set expansion from repo-local workload configuration when requested by the run command.
- [x] 3.4 Implement C++ safetensors reading for tensor inputs referenced by workload records.
- [x] 3.5 Implement deterministic runtime random tensor materialization for workload inputs with matching shapes, dtypes, and CUDA device placement.
- [x] 3.6 Implement destination output allocation from definition output specs and workload axes.

## 4. MoE TVM-FFI Adapter And Runner

- [x] 4.1 Implement the `tvm-ffi-moe` adapter for MoE input order, scalar conversion, destination output order, and `DLTensor`/`tvm::ffi::TensorView` construction.
- [x] 4.2 Ensure the adapter sets the TVM-FFI environment stream to the NVBench launch stream for the timed call and restores the previous stream afterward.
- [x] 4.3 Ensure workload materialization and output allocation happen outside the measured kernel invocation.
- [x] 4.4 Expose runtime-selected workloads as separate NVBench configurations, such as a `workload_index` axis.
- [x] 4.5 Attach workload UUID metadata to NVBench output summaries or configuration labels so timings can be mapped back to source workloads.

## 5. Profiler Run Command And CLI Mapping

- [x] 5.1 Implement the profiler `run` command that validates an existing artifact manifest and runnable binary before launch.
- [x] 5.2 Forward performance options such as `--warmup-runs`, `--iterations`, `--num-trials`, `--timeout`, and `--device` to the artifact runner or NVBench equivalents.
- [x] 5.3 Forward JSON, CSV, and Markdown output options to NVBench.
- [x] 5.4 Reject unsupported correctness-only options such as `--rtol`, `--atol`, and `--required-matched-ratio` with clear messages.
- [x] 5.5 Verify that changing workload selection, timing options, device, random seed, or output format does not trigger artifact recompilation.

## 6. Integration, Documentation, And Checks

- [x] 6.1 Add docs for the build/run workflow, artifact reuse rules, MoE adapter scope, and relationship to official FlashInfer-Bench evaluation.
- [x] 6.2 Add optional Pixi tasks or command examples for configuring, building, and running the C++ profiler in the CUDA 13 environment.
- [x] 6.3 Add non-GPU unit tests or smoke tests for manifest hashing, workload selector resolution, and CLI option mapping.
- [x] 6.4 Add a CUDA-capable manual or integration smoke check that builds a MoE profiler artifact and profiles at least one local MoE workload when dataset and GPU prerequisites are available.
- [x] 6.5 Verify existing `pixi run pack`, `pixi run bench`, project variant commands, and solution packaging behavior remain unchanged. `pixi run bench` was not run because `FIB_DATASET_PATH` is unset in this environment.
- [x] 6.6 Run `openspec validate add-cpp-nvbench-profiler` and record any validation or environment limitations. Validation passed; non-`--skip-compile` artifact build is blocked in this environment by the current NVBench checkout fetching RAPIDS CMake 25.12, which requires CMake 4.0 while the active Pixi environment provides CMake 3.31.
