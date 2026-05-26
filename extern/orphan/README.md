# Local external checkouts

Place local-only external clones or scratch dependency checkouts here. Contents are ignored by Git.

## MLSys 2026 FlashInfer Workloads

The contest workload dataset is cloned here as a shallow, local-only Hugging Face Git/LFS checkout:

```bash
git clone --depth 1 https://huggingface.co/datasets/flashinfer-ai/mlsys26-contest extern/orphan/mlsys26-contest
```

Use it for local benchmark runs by exporting:

```bash
export FIB_DATASET_PATH="$PWD/extern/orphan/mlsys26-contest"
```

The checkout is intentionally under `extern/orphan/`, which is ignored by Git except for this README. Re-clone or update it locally as needed; do not commit dataset files.
