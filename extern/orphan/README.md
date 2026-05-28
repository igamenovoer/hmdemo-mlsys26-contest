# Local external checkouts

Place local-only external clones or scratch dependency checkouts here. Contents are ignored by Git.

## FlashInfer Source

FlashInfer source can be cloned here as a shallow, local-only checkout:

```bash
git clone --depth 1 https://github.com/flashinfer-ai/flashinfer.git extern/orphan/flashinfer
```

Use this checkout for source inspection, references, and local experiments that should not become tracked project dependencies.

## FlashInfer Bench Source

FlashInfer Bench source can be cloned here as a shallow, local-only checkout:

```bash
git clone --depth 1 https://github.com/flashinfer-ai/flashinfer-bench.git extern/orphan/flashinfer-bench
```

Use this checkout for benchmark source inspection and contest workflow reference material.

## CUTLASS Source

CUTLASS source can be cloned here as a shallow, local-only checkout:

```bash
git clone --depth 1 https://github.com/NVIDIA/cutlass.git extern/orphan/cutlass
```

Use this checkout for CUDA kernel design references, CuTe/CUTLASS examples, and experiments that inform contest kernels. If a solution needs CUTLASS headers at submission time, vendor or pack the required files intentionally under the solution bundle instead of relying on this ignored checkout.

## CCCL Source

CCCL source can be cloned here as a shallow, local-only checkout:

```bash
git clone --depth 1 https://github.com/NVIDIA/cccl.git extern/orphan/cccl
```

Use this checkout for CUB, Thrust, libcudacxx, and CUDA Core Library reference material. For contest submissions, keep dependencies header-only and vendor or pack any required headers intentionally instead of relying on this ignored checkout.

## MLSys 2026 FlashInfer Workloads

The contest workload dataset is cloned here as a shallow, local-only Hugging Face Git/LFS checkout:

```bash
git clone --depth 1 https://huggingface.co/datasets/flashinfer-ai/mlsys26-contest extern/orphan/mlsys26-contest
```

Use it for local benchmark runs by exporting:

```bash
export FIB_DATASET_PATH="$PWD/extern/orphan/mlsys26-contest"
```

These checkouts are intentionally under `extern/orphan/`, which is ignored by Git except for this README. Re-clone or update them locally as needed; do not commit source, dataset, or scratch files from this directory.
