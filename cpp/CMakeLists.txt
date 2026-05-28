cmake_minimum_required(VERSION 3.25)

project(hmdemo_nvbench_profile LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(HM_NVPROFILE_BUILD_TESTS "Build profiler C++ tests" ON)
set(HM_NVPROFILE_CUDA_ARCH "100a" CACHE STRING "CUDA architecture used by generated NVBench artifacts")
set(HM_NVPROFILE_NVBENCH_SOURCE "${CMAKE_SOURCE_DIR}/../extern/orphan/nvbench" CACHE PATH "NVBench source checkout")
set(HM_NVPROFILE_TVM_FFI_ROOT "" CACHE PATH "TVM-FFI Python package root or install prefix")
set(HM_NVPROFILE_CUTLASS_INCLUDE_ROOTS "${CMAKE_SOURCE_DIR}/../extern/orphan/cutlass/include;${CMAKE_SOURCE_DIR}/../extern/orphan/cutlass/tools/util/include" CACHE STRING "Semicolon-separated CUTLASS include roots")
set(HM_NVPROFILE_ARTIFACT_ROOT "${CMAKE_SOURCE_DIR}/.cache/artifacts" CACHE PATH "Default profiler artifact root")

find_package(CLI11 REQUIRED)
find_package(fmt REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(tomlplusplus REQUIRED)

add_library(hmdemo_nvbench_profile_core
  src/artifact.cpp
  src/trace.cpp
)
target_include_directories(hmdemo_nvbench_profile_core PUBLIC include)
target_link_libraries(hmdemo_nvbench_profile_core
  PUBLIC
    CLI11::CLI11
    fmt::fmt
    nlohmann_json::nlohmann_json
    tomlplusplus::tomlplusplus
)
target_compile_definitions(hmdemo_nvbench_profile_core
  PUBLIC
    HM_NVPROFILE_VERSION="0.1.0"
    HM_NVPROFILE_DEFAULT_CUDA_ARCH="${HM_NVPROFILE_CUDA_ARCH}"
    HM_NVPROFILE_DEFAULT_NVBENCH_SOURCE="${HM_NVPROFILE_NVBENCH_SOURCE}"
    HM_NVPROFILE_DEFAULT_TVM_FFI_ROOT="${HM_NVPROFILE_TVM_FFI_ROOT}"
    HM_NVPROFILE_DEFAULT_CUTLASS_INCLUDE_ROOTS=""
    HM_NVPROFILE_DEFAULT_ARTIFACT_ROOT="${HM_NVPROFILE_ARTIFACT_ROOT}"
)

add_executable(hm-nvbench-profile src/main.cpp)
target_link_libraries(hm-nvbench-profile PRIVATE hmdemo_nvbench_profile_core)

if(HM_NVPROFILE_BUILD_TESTS)
  enable_testing()
  add_executable(hm-nvbench-profile-smoke tests/smoke.cpp)
  target_link_libraries(hm-nvbench-profile-smoke PRIVATE hmdemo_nvbench_profile_core)
  add_test(NAME hm-nvbench-profile-smoke COMMAND hm-nvbench-profile-smoke)
endif()
