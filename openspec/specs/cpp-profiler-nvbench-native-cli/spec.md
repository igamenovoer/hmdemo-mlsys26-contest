# cpp-profiler-nvbench-native-cli Specification

## Purpose
TBD - created by archiving change make-cpp-profiler-nvbench-native-cli. Update Purpose after archive.
## Requirements
### Requirement: NVBench-native measurement CLI
The C++ profiler `run` command SHALL use NVBench-native option names and semantics for measurement controls when NVBench provides an equivalent.

#### Scenario: Warmup uses NVBench option name
- **WHEN** a developer asks for the profiler `run` help
- **THEN** the CLI lists `--cold-warmup-runs` and does not list `--warmup-runs`

#### Scenario: Samples use NVBench option names
- **WHEN** a developer asks for the profiler `run` help
- **THEN** the CLI lists `--min-samples` and `--target-samples` and does not list `--iterations`

#### Scenario: Device selection uses NVBench option name
- **WHEN** a developer asks for the profiler `run` help
- **THEN** the CLI lists `--devices` and does not list `--device`

### Requirement: FlashInfer-Bench compatibility options are removed
The C++ profiler `run` command SHALL NOT accept FlashInfer-Bench-only correctness or trial options.

#### Scenario: Correctness option is unknown
- **WHEN** a developer runs `hm-nvbench-profile run --rtol 0.1`
- **THEN** CLI parsing fails because `--rtol` is not a supported C++ profiler option

#### Scenario: Trial option is unknown
- **WHEN** a developer runs `hm-nvbench-profile run --num-trials 3`
- **THEN** CLI parsing fails because `--num-trials` is not a supported C++ profiler option

#### Scenario: Required matched ratio option is unknown
- **WHEN** a developer runs `hm-nvbench-profile run --required-matched-ratio 0.9`
- **THEN** CLI parsing fails because `--required-matched-ratio` is not a supported C++ profiler option

### Requirement: Profiler-specific runtime selection remains
The C++ profiler `run` command SHALL keep project-specific runtime selection options that do not have NVBench equivalents.

#### Scenario: Artifact and workload options remain available
- **WHEN** a developer asks for the profiler `run` help
- **THEN** the CLI lists `--artifact`, `--local`, `--definition`, `--workload`, and `--workload-set`

#### Scenario: Workload selection remains runtime-only
- **WHEN** a developer changes `--workload` or `--workload-set` between profiler runs
- **THEN** the profiler reuses the existing artifact and does not rebuild solely because workload selection changed

### Requirement: NVBench stopping and output controls remain
The C++ profiler `run` command SHALL keep NVBench-native stopping, timeout, and output controls.

#### Scenario: Stopping controls remain available
- **WHEN** a developer asks for the profiler `run` help
- **THEN** the CLI lists `--stopping-criterion`, `--min-samples`, `--target-samples`, `--max-noise`, `--min-time`, and `--timeout`

#### Scenario: Output controls remain available
- **WHEN** a developer asks for the profiler `run` help
- **THEN** the CLI lists `--json`, `--csv`, and `--markdown`

#### Scenario: Native options forward to runner
- **WHEN** a developer runs the profiler with `--cold-warmup-runs`, `--devices`, `--stopping-criterion`, `--min-samples`, and `--target-samples`
- **THEN** the profiler forwards those NVBench-native options to the artifact runner without requiring FlashInfer-Bench-style aliases

### Requirement: NVBench-native documentation
The repository SHALL document the C++ profiler `run` command as an NVBench-native timing interface rather than a FlashInfer-Bench-compatible benchmark interface.

#### Scenario: Developer reads profiler docs
- **WHEN** a developer opens the C++ profiler documentation
- **THEN** the examples use `--cold-warmup-runs`, `--devices`, `--min-samples`, and `--target-samples` rather than `--warmup-runs`, `--device`, or `--iterations`

#### Scenario: Developer sees migration guidance
- **WHEN** a developer reads the C++ profiler documentation
- **THEN** the documentation explains that official correctness and comparison workflows remain under FlashInfer-Bench and are not modeled by the C++ profiler CLI

