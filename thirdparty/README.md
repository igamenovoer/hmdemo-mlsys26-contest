# Third-Party Install Prefixes

`thirdparty/` is a local install prefix for generated or installable third-party library trees. Keep this directory reproducible and disposable: source checkouts live under `extern/orphan/`, while installed headers, CMake package files, libraries, and generated test/install directories live here.

Use `thirdparty/` for dependencies consumed by code paths that are not managed by Conan, such as `solution/` code, generated contest artifacts, packer-visible include roots, or local CUDA experiments that need stable repo-relative headers. For Conan-managed C++ sources under `cpp/`, prefer declaring dependencies in `cpp/conanfile.py` and consuming them through Conan-generated CMake targets instead of pointing at `thirdparty/`.

## Current Contents

| Path | Source | Purpose | Tracked |
|---|---|---|---|
| `thirdparty/cutlass/` | `extern/orphan/cutlass/` | Local CUTLASS/CuTe CMake install prefix for solution-visible headers, including `tools/util` headers such as `cutlass/util/packed_stride.hpp`. | No |

Only this `README.md` and `.gitignore` should be tracked. Installed library contents are ignored because they can be regenerated from `extern/orphan/` checkouts.

## Recreate In A Fresh Checkout

1. Clone or refresh the orphan source checkout:

```bash
mkdir -p extern/orphan
git clone --depth=1 https://github.com/NVIDIA/cutlass.git extern/orphan/cutlass
```

If `extern/orphan/cutlass` already exists, update it intentionally or remove and reclone it.

2. Configure and install CUTLASS into `thirdparty/cutlass`:

```bash
cmake -S extern/orphan/cutlass -B tmp/build/cutlass-install \
  -DCMAKE_INSTALL_PREFIX="$PWD/thirdparty/cutlass" \
  -DCUTLASS_ENABLE_HEADERS_ONLY=ON \
  -DCUTLASS_ENABLE_TOOLS=ON \
  -DCUTLASS_ENABLE_LIBRARY=OFF \
  -DCUTLASS_ENABLE_PROFILER=OFF \
  -DCUTLASS_ENABLE_TESTS=OFF \
  -DCUTLASS_INSTALL_TESTS=OFF
cmake --build tmp/build/cutlass-install --target install
```

This produces core CUTLASS/CuTe headers under `thirdparty/cutlass/include/`, installs CUTLASS tool utility headers under `thirdparty/cutlass/include/cutlass/util/`, and writes CMake package metadata under `thirdparty/cutlass/lib/cmake/NvidiaCutlass/`. The installed CMake package exports both `nvidia::cutlass::cutlass` and `nvidia::cutlass::tools::util`.

## Notes

- Do not make submission code depend on `thirdparty/`; it is local-only and ignored.
- For contest solution packaging, vendor required headers into the solution bundle or pack them through the project packer deliberately.
- For Conan-managed `cpp/` tooling, use Conan packages when available; reserve `thirdparty/` for libraries or headers used outside that Conan dependency graph.
- Prefer CUDA Toolkit headers visible to `nvcc` for CCCL/CUB/Thrust/libcu++ before adding local install prefixes.
