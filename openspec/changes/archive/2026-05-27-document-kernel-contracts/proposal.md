## Why

Kernel authors need the concrete callable interface for contest definitions before they can create minimal runnable CUDA kernels that build and can enter the benchmark path. The current documentation does not collect the MoE and DSA TVM-FFI destination-passing signatures in one repo-local page.

## What Changes

- Add a contest documentation page for MoE and DSA kernel contracts.
- Record the exact definition IDs required by the dataset and local benchmark tools.
- Document the TVM-FFI destination-passing call surface used by this repository: inputs first, output tensors last.
- Include fixed geometry, input/output order, scalar C++ types, and signature sketches for MoE, DSA sparse attention, and DSA top-k indexer.
- Note that local timing requires correctness to pass before performance is measured.

## Capabilities

### New Capabilities

- `contest-kernel-contracts`: Documents contest kernel interfaces needed to build minimal runnable kernels for MoE and DSA.

### Modified Capabilities

- None.

## Impact

- Adds documentation under `docs/contest/`.
- Adds an accepted OpenSpec capability for maintaining kernel-contract documentation.
- Does not change solution code, build code, benchmark scripts, runtime dependencies, or generated artifacts.
