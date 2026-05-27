# Runtime Optimization Skills

This directory exposes CUDA kernel optimization skills for agents optimizing contest kernels, whether the workflow is automatic or human-assisted.

The skills here are symlinks to the tracked domain-skill source tree at `../../extern/tracked/domain-skills/domain/cuda/`. Keep that external tree as the source of truth, and add or update runtime CUDA optimization skills there before linking them here.

Current runtime skills:

- `krnopt-cuda-coding`
- `krnopt-cuda-domain-optimization`
- `krnopt-cuda-generic-optimization`
- `krnopt-cuda-profiling`
- `krnopt-cuda-structural-optimization`
- `krnopt-hw-aware-optimization`
- `krnopt-low-precision-kernel-formats`

Do not put general project development or maintenance skills here; those belong in `../dev/`.
