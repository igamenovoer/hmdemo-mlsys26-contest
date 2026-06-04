# Compute

## Local GPU Posture

- The live loop assumes local CUDA/GPU availability for Coder local checks and Profiler tool use.
- Runtime or harness material should pick a spare local GPU for checks and profiling instead of hardcoding one GPU id.
- If no spare local GPU is available, the affected work should enter waiting-for-GPU state instead of immediately failing.

## Evidence Role

- Local GPU checks are exploratory evidence.
- Profiler output from local GPU runs can guide planning, synthesis, and evaluation review.
- Current-best updates still require accepted Evaluator promotion evidence from `official-timing`.

## Modal Posture

- Modal is not the default path for Coder local checks or profiler tool use.
- Modal may be used later only through an explicit operator-directed or generated fallback path if that is added.

## Open

- Non-GPU blocker retry details are owned by `failure-policy.md`.
