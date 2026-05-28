# nvbench-stopping-cli Specification

## Purpose
TBD - created by archiving change expose-nvbench-stopping-cli. Update Purpose after archive.
## Requirements
### Requirement: Stopping criterion CLI
The C++ NVBench profiler SHALL expose a `run` CLI option for selecting the NVBench stopping criterion used by the artifact runner.

#### Scenario: Fixed sample-count criterion is the default
- **WHEN** a developer runs `hm-nvbench-profile run` without specifying a stopping criterion
- **THEN** the profiler forwards NVBench arguments that use the `sample-count` stopping criterion

#### Scenario: Developer selects stdrel criterion
- **WHEN** a developer runs `hm-nvbench-profile run --stopping-criterion stdrel`
- **THEN** the profiler forwards `--stopping-criterion stdrel` to the artifact runner

#### Scenario: Unsupported criterion is rejected
- **WHEN** a developer runs `hm-nvbench-profile run --stopping-criterion unsupported`
- **THEN** the profiler fails before launching the artifact runner with a clear invalid criterion error

### Requirement: Sample-count controls
The C++ NVBench profiler SHALL expose runtime CLI options for controlling NVBench sample counts without changing artifact build identity.

#### Scenario: Iterations remain a compatibility alias
- **WHEN** a developer runs `hm-nvbench-profile run --iterations 100`
- **THEN** the profiler forwards NVBench sample-count arguments equivalent to `--min-samples 100 --target-samples 100`

#### Scenario: Explicit min and target samples are forwarded
- **WHEN** a developer runs `hm-nvbench-profile run --min-samples 20 --target-samples 80`
- **THEN** the profiler forwards `--min-samples 20 --target-samples 80` to the artifact runner

#### Scenario: Sample controls are runtime-only
- **WHEN** a developer changes `--iterations`, `--min-samples`, or `--target-samples` between profiler runs
- **THEN** the profiler reuses the existing artifact and does not rebuild solely because those timing options changed

### Requirement: Variance convergence controls
The C++ NVBench profiler SHALL expose runtime CLI options for NVBench `stdrel` convergence parameters.

#### Scenario: Max noise is forwarded for stdrel
- **WHEN** a developer runs `hm-nvbench-profile run --stopping-criterion stdrel --max-noise 0.25`
- **THEN** the profiler forwards `--stopping-criterion stdrel --max-noise 0.25` to the artifact runner

#### Scenario: Min time is forwarded for stdrel
- **WHEN** a developer runs `hm-nvbench-profile run --stopping-criterion stdrel --min-time 0.2`
- **THEN** the profiler forwards `--stopping-criterion stdrel --min-time 0.2` to the artifact runner

#### Scenario: Variance option implies stdrel when criterion is omitted
- **WHEN** a developer runs `hm-nvbench-profile run --max-noise 0.5` without a stopping criterion
- **THEN** the profiler forwards `--stopping-criterion stdrel --max-noise 0.5` to the artifact runner

#### Scenario: Variance option rejects incompatible criterion
- **WHEN** a developer runs `hm-nvbench-profile run --stopping-criterion sample-count --max-noise 0.5`
- **THEN** the profiler fails before launching the artifact runner with a clear message that `--max-noise` requires the `stdrel` stopping criterion

### Requirement: Timing option documentation
The repository SHALL document how profiler timing CLI options map to NVBench runner arguments.

#### Scenario: Developer reads profiler docs
- **WHEN** a developer opens the C++ NVBench profiler documentation
- **THEN** the documentation explains `--iterations`, `--min-samples`, `--target-samples`, `--stopping-criterion`, `--max-noise`, and `--min-time`

