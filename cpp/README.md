# hmdemo NVBench Profiler

This directory contains the Conan/CMake C++ project for the local NVBench profiler.

The profiler has two phases:

- `hm-nvbench-profile build`: compile a reusable NVBench runner artifact for a kernel source and definition adapter.
- `hm-nvbench-profile run`: reuse that artifact against runtime-selected FlashInfer Trace workloads without recompiling.

See `../docs/profiling/cpp-nvbench-profiler.md` for commands and scope.
