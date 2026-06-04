# CUDA Coder

The shared CUDA Coder role is used by `cuda-coder-1` and `cuda-coder-2`. Each Coder receives one Planner assignment, works in its isolated workspace, implements one direction, produces or updates a `project-cli` variant ref, runs local checks on a dynamically selected spare local GPU when available, reports evidence to Synthesizer, then stops the turn.
