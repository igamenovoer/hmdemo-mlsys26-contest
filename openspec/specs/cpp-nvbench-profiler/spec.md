# cpp-nvbench-profiler Specification

## Purpose
TBD - created by archiving change add-cpp-nvbench-profiler. Update Purpose after archive.
## Requirements
### Requirement: Conan-compatible C++ profiler project
The repository SHALL provide a standard C++ project under `cpp/` for the NVBench profiler with Conan-compatible dependency metadata and CMake build targets.

#### Scenario: Developer discovers C++ profiler project
- **WHEN** a developer lists the repository root after this change
- **THEN** `cpp/` contains Conan project metadata and CMake configuration for building the profiler tooling

#### Scenario: C++ dependencies are declared outside Python packaging
- **WHEN** a developer inspects the C++ profiler project metadata
- **THEN** normal C++ dependencies such as CLI parsing, JSON parsing, and formatting are declared in the Conan-compatible project configuration rather than the Python package metadata

### Requirement: Profiler artifact build command
The profiler SHALL provide a build command that compiles a reusable NVBench runner artifact for a kernel source, definition adapter, CUDA build configuration, and include or dependency roots.

#### Scenario: Build creates reusable artifact
- **WHEN** a developer runs the profiler build command with a CUDA kernel path, `tvm-ffi-moe` adapter, CUDA architecture, and required include roots
- **THEN** the command creates an artifact directory containing a runnable NVBench binary and an artifact manifest

#### Scenario: Build manifest records build inputs
- **WHEN** the build command creates an artifact
- **THEN** the artifact manifest records the kernel source identity, adapter, definition identity, compiler configuration, CUDA architecture, dependency roots, and profiler version metadata needed to decide whether the artifact is reusable

### Requirement: Artifact reuse is independent of workload selection
The profiler SHALL NOT include workload UUIDs, workload sets, dataset root paths, random seeds, device IDs, timing options, or output-format options in the build identity that determines whether an artifact must be rebuilt.

#### Scenario: Different workload reuses artifact
- **WHEN** a developer builds an artifact for a kernel and then runs the profiler against two different workload UUID selections
- **THEN** the second run reuses the existing artifact without recompiling solely because the workload selection changed

#### Scenario: Kernel edit invalidates artifact
- **WHEN** the kernel source content changes after an artifact was built
- **THEN** the profiler detects that the existing artifact no longer matches the build inputs and requires a rebuild or creates a new artifact

### Requirement: Profiler run command
The profiler SHALL provide a run command that executes an existing profiler artifact against one or more runtime-selected workloads.

#### Scenario: Run executes existing artifact
- **WHEN** a developer runs the profiler run command with an artifact path, local dataset root, definition, and workload selector
- **THEN** the command launches the artifact's NVBench runner using the selected workloads without invoking the artifact build step

#### Scenario: Missing artifact is rejected
- **WHEN** a developer runs the profiler run command with an artifact path that does not contain a valid runnable binary and manifest
- **THEN** the command fails with an error explaining that the artifact must be built first

### Requirement: FlashInfer Trace workload loading
The profiler SHALL load local FlashInfer Trace-style definition and workload data at runtime for the selected definition and workload selectors.

#### Scenario: Load workload by UUID prefix
- **WHEN** a developer requests a workload by exact UUID or unique UUID prefix
- **THEN** the profiler resolves it to one workload record for the selected definition

#### Scenario: Ambiguous workload selector fails
- **WHEN** a developer requests a workload selector that matches multiple workload UUIDs
- **THEN** the profiler fails and reports the selector as ambiguous

#### Scenario: Load workload set
- **WHEN** a developer requests a named workload set supported by the repo-local workload configuration
- **THEN** the profiler expands the set to exact workload records before launching the artifact

### Requirement: Runtime workload materialization
The profiler SHALL materialize selected workload inputs and output tensors at runtime in C++ without using FlashInfer-Bench or Python.

#### Scenario: Materialize tensor and scalar inputs
- **WHEN** a selected workload includes safetensors inputs, random inputs, and scalar inputs
- **THEN** the profiler loads safetensors tensors, creates random CUDA tensors with matching shapes and dtypes, and passes scalar values in the adapter-defined order

#### Scenario: Allocate destination outputs
- **WHEN** a selected workload is materialized for a destination-passing kernel
- **THEN** the profiler allocates output tensors with shapes and dtypes derived from the selected definition and workload axes

### Requirement: MoE TVM-FFI adapter
The profiler SHALL include an initial `tvm-ffi-moe` adapter for the contest MoE TVM-FFI destination-passing kernel signature.

#### Scenario: Adapter constructs TensorView arguments
- **WHEN** the `tvm-ffi-moe` adapter runs a materialized MoE workload
- **THEN** it constructs `DLTensor` descriptors and `tvm::ffi::TensorView` arguments in the MoE definition input order followed by the destination output

#### Scenario: Adapter sets NVBench stream
- **WHEN** the `tvm-ffi-moe` adapter invokes the kernel inside an NVBench measurement
- **THEN** it sets the TVM-FFI environment stream for the active CUDA device to the NVBench launch stream for the timed call and restores the previous stream afterward

### Requirement: Timing-only NVBench measurement
The profiler SHALL time only the solution kernel invocation inside NVBench and SHALL NOT compute reference outputs, perform correctness checks, or report FlashInfer-Bench speedups.

#### Scenario: Kernel call is timed
- **WHEN** the NVBench runner profiles a materialized workload
- **THEN** input materialization and output allocation occur outside the measured kernel invocation

#### Scenario: Correctness options are not accepted as profiling semantics
- **WHEN** a developer passes correctness-only options such as `--rtol`, `--atol`, or `--required-matched-ratio`
- **THEN** the profiler rejects those options or reports that they are unsupported for timing-only profiling

### Requirement: Performance CLI compatibility
The profiler SHALL expose performance-related CLI options that map to NVBench controls where a meaningful equivalent exists.

#### Scenario: Iteration and warmup options map to NVBench
- **WHEN** a developer runs the profiler with `--warmup-runs`, `--iterations`, and `--timeout`
- **THEN** the profiler forwards equivalent NVBench warmup, sample-count, and timeout controls to the artifact runner

#### Scenario: Output format options map to NVBench
- **WHEN** a developer requests JSON, CSV, or Markdown output
- **THEN** the profiler forwards the corresponding NVBench output option to the artifact runner

### Requirement: Workload sweep without recompilation
The artifact runner SHALL support sweeping multiple runtime-selected workloads in a single NVBench run.

#### Scenario: Multiple workloads become NVBench configurations
- **WHEN** a developer profiles multiple workload UUIDs with one artifact
- **THEN** the runner exposes each selected workload as a separate NVBench configuration, such as through a runtime `workload_index` axis

#### Scenario: Output identifies workload
- **WHEN** the runner emits NVBench results for a workload sweep
- **THEN** each measured configuration includes enough workload identity metadata to map the timing result back to the source workload UUID

### Requirement: Existing benchmark workflows remain unchanged
The C++ NVBench profiler SHALL NOT change the behavior of existing FlashInfer-Bench, packing, Modal benchmark, or project variant workflows.

#### Scenario: Existing Python benchmark task remains available
- **WHEN** the C++ profiler is added
- **THEN** `pixi run bench` continues to use the existing FlashInfer-Bench local benchmark path

#### Scenario: Solution packaging remains unchanged
- **WHEN** the C++ profiler builds or runs an artifact
- **THEN** generated profiler artifacts are not included in `solution.json` by the existing packer

