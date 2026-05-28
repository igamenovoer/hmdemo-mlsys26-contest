# Runtime Optimization Skills

This directory exposes CUDA kernel optimization and runtime operation skills for agents optimizing contest kernels, whether the workflow is automatic or human-assisted.

Most CUDA optimization skills here are symlinks to the tracked domain-skill source tree at `../../extern/tracked/domain-skills/domain/cuda/`. Keep that external tree as the source of truth for generic CUDA optimization guidance, and add or update generic runtime CUDA optimization skills there before linking them here. Project-specific runtime operation skills may live directly in this directory.

Current runtime skills:

- `krnopt-cuda-coding`
- `krnopt-cuda-domain-optimization`
- `krnopt-cuda-generic-optimization`
- `krnopt-cuda-profiling`
- `krnopt-cuda-structural-optimization`
- `krnopt-hw-aware-optimization`
- `krnopt-low-precision-kernel-formats`
- `project-op-variant-profiling`

Do not put general project development or maintenance skills here; those belong in `../dev/`.
