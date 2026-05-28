# Contest Kernel Contracts Specification

## Purpose

Define documentation requirements for contest kernel interfaces needed to build minimal runnable CUDA TVM-FFI kernels.

## Requirements

### Requirement: MoE And DSA Kernel Contract Documentation

The repository SHALL document the MoE and DSA contest kernel contracts needed to create minimal runnable CUDA TVM-FFI kernels.

#### Scenario: Kernel author finds callable signatures

- **WHEN** a kernel author reads the contest kernel contract documentation
- **THEN** it lists the exact MoE and DSA definition IDs, input order, output order, scalar C++ types, and TVM-FFI destination-passing signatures

### Requirement: Contract Source Alignment

The kernel contract documentation SHALL state that the local dataset definitions and `flashinfer_bench` destination-passing call path are the source of truth for callable interfaces.

#### Scenario: Definition interface changes

- **WHEN** a local dataset definition changes its inputs or outputs
- **THEN** the documentation identifies the local definition files as the verification target for updating the contract

### Requirement: Timing Boundary Note

The kernel contract documentation SHALL state that local benchmarking checks correctness before timing contributes to a passed result.

#### Scenario: Minimal kernel is runnable but incorrect

- **WHEN** a minimal kernel builds and runs but produces incorrect outputs
- **THEN** the documentation warns that the evaluator reports correctness failure before performance timing is accepted
