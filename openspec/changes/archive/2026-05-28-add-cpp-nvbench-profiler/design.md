## Context

The repository currently profiles contest kernels through FlashInfer-Bench, which packages the solution, builds it through the selected builder, materializes workloads, computes reference outputs, checks correctness, and then records timing. That path is the official pass/fail surface and should remain intact, but it is heavier than needed for local kernel iteration when the developer only wants timing across different workload slices.

NVBench is a C++/CUDA benchmark framework whose benchmark bodies are compiled into the executable. That means a profiler accepting a `.cu` kernel cannot avoid a compile step entirely, but it can avoid recompilation when only the workload selection changes. The profiler should therefore compile a reusable artifact keyed by source/build inputs, then run that artifact repeatedly with workload data and performance options supplied at runtime.

The initial kernel target is the MoE CUDA TVM-FFI variant. It exports `kernel.cu::kernel` for FlashInfer-Bench and internally exposes C++ code that can be called with `tvm::ffi::TensorView` arguments. The generated or compiled profiler adapter can include or link the kernel source, construct `DLTensor` descriptors over CUDA allocations, set the TVM-FFI stream context to the NVBench stream, and time only the kernel call. Future definitions can add adapters without changing the build/run model.

## Goals / Non-Goals

**Goals:**

- Add a Conan-compatible C++ project under `cpp/` with a profiler CLI and reusable build artifacts.
- Separate artifact build from workload profiling so a kernel is compiled once for a definition adapter and then reused across workload selections.
- Support an initial MoE TVM-FFI adapter for the contest MoE destination-passing signature.
- Load FlashInfer Trace-style local definitions and workloads in C++ at runtime.
- Materialize tensor inputs, scalar inputs, and output tensors without invoking FlashInfer-Bench or Python.
- Time only the solution kernel with NVBench and expose NVBench JSON/CSV/Markdown output.
- Provide performance-related CLI options similar to FlashInfer-Bench where they have a meaningful NVBench equivalent.

**Non-Goals:**

- Do not replace `pixi run bench`, `flashinfer-bench run`, Modal benchmarking, or official correctness-gated evaluation.
- Do not compute reference outputs, compare correctness, or report speedup against the FlashInfer baseline.
- Do not make the C++ profiler part of the default Python unit-test path.
- Do not support arbitrary CUDA signatures in the first iteration; use explicit definition adapters.
- Do not package generated profiler artifacts into `solution.json`.

## Decisions

### Decision: Use an explicit `build` / `run` split

The profiler CLI should expose `build` to produce a reusable artifact and `run` to execute that artifact against workload data. The artifact should contain the compiled NVBench runner, the selected adapter, copied or referenced kernel source metadata, and a manifest describing the inputs that affect rebuilds.

Alternative considered: make `run --kernel ...` generate and compile a benchmark binary every time. That is simpler to explain but punishes common profiling workflows where the developer changes only `--workload`, `--workload-set`, `--device`, `--iterations`, or output format.

### Decision: Key artifacts by build inputs, not runtime workload inputs

The artifact identity should include kernel source content, adapter name, definition name or signature, CUDA architecture, compiler flags, include roots, NVBench source/version, TVM-FFI include/library roots, and relevant CMake/Conan profile data. It should not include workload UUIDs, dataset path, random seed, device, measurement settings, or output format.

Alternative considered: one artifact per workload set. That would simplify runtime context, but it recreates the compile-per-workload problem.

### Decision: Use definition adapters instead of a fully generic kernel ABI

The initial adapter should be `tvm-ffi-moe`, responsible for MoE input order, scalar types, output allocation, `DLTensor` construction, TVM-FFI stream context setup, and the direct call into the compiled kernel. The adapter boundary can later support DSA or GDN definitions with separate compiled call shims.

Alternative considered: force users to provide a custom benchmark harness for every kernel. That is flexible but loses the purpose of a repo-local profiling tool with consistent workload loading and CLI behavior.

### Decision: Keep workload materialization runtime-owned

The runner should parse definition/workload metadata at runtime, load safetensors data from the local trace root, generate random tensors deterministically, pass scalar values, allocate destination tensors, and provide a dynamic NVBench axis such as `workload_index`. `hm-nvbench-profile run` can pass NVBench axis overrides to sweep the loaded workload list.

Alternative considered: bake workloads into generated C++ during build. That would make the generated runner self-contained but would require recompilation for every workload selection.

### Decision: Let NVBench own measurement, with FlashInfer-like aliases

The wrapper CLI should translate familiar performance knobs into NVBench arguments where possible: `--iterations` maps to sample-count target samples, `--warmup-runs` maps to cold warmup runs, `--timeout` maps to NVBench timeout, and output flags map to NVBench JSON/CSV/Markdown. Correctness-only options such as `--rtol`, `--atol`, and `--required-matched-ratio` should be omitted or rejected for this profiler rather than silently implying correctness.

Alternative considered: reimplement timing loops manually with CUDA events. That would provide exact FlashInfer-Bench-like controls, but it would discard NVBench’s reporting, device metadata, stopping criteria, and profiling ergonomics.

### Decision: Treat Conan as the C++ project interface and CMake as the build engine

The `cpp/` project should be buildable with a standard Conan workflow for normal C++ dependencies such as CLI parsing, JSON parsing, and formatting. CUDA Toolkit, NVBench, CUTLASS headers, and TVM-FFI may be discovered through CMake options or environment paths because they are local development dependencies with CUDA-specific constraints.

Alternative considered: drive everything from Pixi-only Python scripts. Pixi tasks can wrap the tool, but the profiler itself should remain a standard C++ project.

## Risks / Trade-offs

- NVBench artifacts may accidentally rebuild too often if the manifest hash includes runtime-only settings -> Mitigate by defining separate build-input and run-input schemas and testing workload changes against a stable artifact.
- Directly including `kernel.cu` in the runner may conflict with exported symbols or compile flags -> Mitigate by compiling the adapter and kernel as controlled CMake targets and documenting required include roots and macros.
- TVM-FFI stream handling could measure the wrong stream if the adapter does not set the environment stream -> Mitigate by setting `TVMFFIEnvSetStream(kDLCUDA, device, launch.get_stream(), &old_stream)` around the timed call and restoring the previous stream.
- C++ safetensors loading and random materialization may diverge from FlashInfer-Bench input generation -> Mitigate by keeping the profiler explicitly timing-oriented, documenting that it is not a correctness oracle, and matching tensor shapes/dtypes/device placement needed by the kernel contract.
- Large workloads may make input allocation dominate run startup -> Mitigate by materializing inputs outside `state.exec` and timing only the kernel call.
- Conan/NVBench/CUDA version friction can slow adoption -> Mitigate by providing clear CMake options and Pixi wrapper tasks for the known CUDA 13 local environment.

## Migration Plan

First add the `cpp/` project scaffold, Conan metadata, CMake targets, and documentation. Next implement artifact manifesting and the `build` command for a generated or configured MoE runner. Then implement runtime workload loading, materialization, and the `run` command that forwards NVBench measurement options. Finally add smoke checks for artifact reuse and a small workload timing path that can run only in CUDA-capable manual/integration environments. Rollback is to leave the `cpp/` profiler unused; existing Python packaging and FlashInfer-Bench workflows are unaffected.

## Open Questions

- Should `run --kernel ...` exist as a convenience that resolves or builds an artifact automatically, or should the first interface require explicit `build` followed by explicit `run`?
- Should generated artifacts copy kernel sources into the artifact directory for reproducibility, or reference the original source path plus hash?
- Should the initial C++ random materializer match FlashInfer-Bench random distributions exactly, or only produce valid deterministic inputs with matching dtype and shape?
- Should profiling output be raw NVBench JSON only, or should the wrapper also summarize latency by workload UUID in a FlashInfer-Bench-like table?
