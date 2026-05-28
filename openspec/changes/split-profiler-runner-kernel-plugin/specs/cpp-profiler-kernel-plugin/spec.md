## ADDED Requirements

### Requirement: Static NVBench runner
The C++ profiler SHALL build the NVBench runner and profiler runtime as part of the normal `cpp/` project rather than generating and compiling a complete runner project per kernel artifact.

#### Scenario: C++ build creates static runner
- **WHEN** a developer runs the normal C++ profiler build
- **THEN** the build produces the profiler CLI and a reusable NVBench runner component that can run multiple kernel plugins without recompiling runner code

#### Scenario: Kernel build does not compile NVBench
- **WHEN** a developer builds a kernel plugin artifact
- **THEN** the plugin build does not configure or compile NVBench or the profiler runtime again

### Requirement: Kernel plugin build artifact
The profiler build command SHALL compile a selected CUDA kernel source into a shared-library plugin artifact with a manifest.

#### Scenario: Build creates plugin library
- **WHEN** a developer runs the profiler build command with a CUDA kernel path, `tvm-ffi-moe` adapter, CUDA architecture, and required include roots
- **THEN** the command creates an artifact directory containing a plugin shared library and `manifest.json`

#### Scenario: Manifest records plugin path
- **WHEN** the build command writes the artifact manifest
- **THEN** the manifest records the plugin shared library path, plugin ABI version, adapter, definition identity, kernel source identity, compiler options, CUDA architecture, and dependency roots

#### Scenario: Build artifact excludes runner binary
- **WHEN** the build command creates a plugin artifact
- **THEN** the artifact does not contain an artifact-local NVBench runner executable as the primary runnable output

### Requirement: Stable plugin C ABI
The kernel plugin SHALL export a stable profiler-controlled C ABI for the `tvm-ffi-moe` adapter.

#### Scenario: Plugin exports ABI metadata
- **WHEN** the profiler loads a plugin artifact
- **THEN** the plugin exposes symbols that allow the profiler to validate ABI version and adapter identity before timing

#### Scenario: Plugin exports MoE entrypoint
- **WHEN** the plugin is built for `tvm-ffi-moe`
- **THEN** the plugin exports a C ABI entrypoint that accepts MoE tensor arguments as `DLTensor*`, scalar arguments, and an output `DLTensor*`

#### Scenario: Shim invokes solution kernel
- **WHEN** the static runner calls the plugin MoE entrypoint
- **THEN** the generated shim constructs `tvm::ffi::TensorView` arguments and invokes the selected kernel's `moe_tvm_ffi::Kernel`

### Requirement: Runtime plugin loading
The profiler run command SHALL load and validate a plugin artifact at runtime before registering or executing NVBench measurements.

#### Scenario: Run loads plugin
- **WHEN** a developer runs the profiler with a plugin artifact path, local dataset root, definition, and workload selector
- **THEN** the static runner loads the plugin shared library with dynamic loading and resolves the MoE entrypoint before launching NVBench measurements

#### Scenario: Missing plugin is rejected
- **WHEN** a developer runs the profiler with an artifact manifest whose plugin shared library is missing
- **THEN** the command fails with an error explaining that the plugin artifact must be built first

#### Scenario: ABI mismatch is rejected
- **WHEN** a plugin reports an unsupported ABI version or adapter identity
- **THEN** the profiler fails before timing with a clear plugin ABI mismatch error

### Requirement: Static runner preserves measurement behavior
The static runner SHALL preserve the existing timing-only measurement semantics while replacing direct kernel linkage with plugin dispatch.

#### Scenario: Kernel call is timed through plugin
- **WHEN** the NVBench runner profiles a materialized workload
- **THEN** input materialization, plugin loading, and output allocation occur outside the measured region, and only the plugin entrypoint invocation is timed

#### Scenario: Stream context is set for plugin call
- **WHEN** the runner invokes the plugin entrypoint inside an NVBench measurement
- **THEN** the runner sets the TVM-FFI environment stream for the active CUDA device to the NVBench launch stream for the timed call and restores the previous stream afterward

#### Scenario: Workload sweep remains supported
- **WHEN** a developer profiles multiple workload UUIDs with one plugin artifact
- **THEN** the runner exposes each selected workload as a separate NVBench configuration and includes workload identity metadata in the output

### Requirement: Plugin artifact reuse is independent of runtime selection
The plugin artifact build identity SHALL exclude runtime workload, timing, output, and device inputs.

#### Scenario: Different workload reuses plugin
- **WHEN** a developer builds a plugin artifact for a kernel and then runs the profiler against two different workload UUID selections
- **THEN** the second run reuses the existing plugin artifact without recompiling solely because workload selection changed

#### Scenario: Kernel edit invalidates plugin
- **WHEN** the kernel source content changes after a plugin artifact was built
- **THEN** the profiler detects that the existing plugin artifact no longer matches build inputs and requires a rebuild or creates a new plugin artifact

### Requirement: Plugin architecture documentation
The repository SHALL document the static-runner plus kernel-plugin architecture.

#### Scenario: Developer reads profiler docs
- **WHEN** a developer opens the C++ profiler documentation
- **THEN** the documentation explains that the profiler runner is built once and kernel variants are compiled as plugin shared libraries loaded at runtime

#### Scenario: Developer reads build guidance
- **WHEN** a developer reads the build command documentation
- **THEN** the documentation explains which inputs rebuild the plugin and which runtime inputs do not affect plugin identity
