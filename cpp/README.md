# hmdemo NVBench Profiler

This directory contains the Conan/CMake C++ project for the local NVBench profiler.

The profiler has two phases:

- `hm-nvbench-profile build`: compile a per-kernel plugin shared library for a kernel source and definition adapter.
- `hm-nvbench-profile run`: load that plugin into the reusable NVBench runner against runtime-selected FlashInfer Trace workloads without recompiling the kernel.

See `../docs/profiling/cpp-nvbench-profiler.md` for commands and scope.
