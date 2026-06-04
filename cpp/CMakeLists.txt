cmake_minimum_required(VERSION 3.25)

project(hmdemo_nvbench_profile LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(HM_NVPROFILE_BUILD_TESTS "Build profiler C++ tests" ON)
option(HM_NVPROFILE_BUILD_STATIC_RUNNER "Build reusable CUDA/NVBench runner target" OFF)
set(HM_NVPROFILE_CUDA_ARCH "100a" CACHE STRING "CUDA architecture used by generated profiler plugins and runner")
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
  src/plugin_loader.cpp
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
target_link_libraries(hmdemo_nvbench_profile_core PUBLIC ${CMAKE_DL_LIBS})
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

if(HM_NVPROFILE_BUILD_STATIC_RUNNER)
  enable_language(CUDA)
  find_package(CUDAToolkit REQUIRED)
  find_package(nlohmann_json REQUIRED)
  set(NVBench_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
  set(NVBench_ENABLE_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(NVBench_ENABLE_CUPTI OFF CACHE BOOL "" FORCE)
  set(NVBench_ENABLE_NVML ON CACHE BOOL "" FORCE)
  add_subdirectory("${HM_NVPROFILE_NVBENCH_SOURCE}" nvbench-build)
  add_executable(hm-nvbench-runner runner/runner.cu)
  target_include_directories(hm-nvbench-runner PRIVATE
    include
    "${HM_NVPROFILE_TVM_FFI_ROOT}/include"
    "${HM_NVPROFILE_TVM_FFI_ROOT}/3rdparty/dlpack/include"
  )
  target_link_directories(hm-nvbench-runner PRIVATE "${HM_NVPROFILE_TVM_FFI_ROOT}/lib")
  target_link_libraries(hm-nvbench-runner PRIVATE
    hmdemo_nvbench_profile_core
    nvbench::main
    nlohmann_json::nlohmann_json
    CUDA::cudart
    tvm_ffi
  )
  set_target_properties(hm-nvbench-runner PROPERTIES
    BUILD_RPATH "${HM_NVPROFILE_TVM_FFI_ROOT}/lib"
  )
endif()

if(HM_NVPROFILE_BUILD_TESTS)
  enable_testing()
  add_library(hm-nvbench-profile-missing-entry-plugin SHARED tests/bad_plugin.cpp)
  target_include_directories(hm-nvbench-profile-missing-entry-plugin PRIVATE include)
  target_compile_definitions(hm-nvbench-profile-missing-entry-plugin PRIVATE HM_NVPROFILE_BAD_PLUGIN_MISSING_ENTRY)

  add_library(hm-nvbench-profile-wrong-abi-plugin SHARED tests/bad_plugin.cpp)
  target_include_directories(hm-nvbench-profile-wrong-abi-plugin PRIVATE include)
  target_compile_definitions(hm-nvbench-profile-wrong-abi-plugin PRIVATE HM_NVPROFILE_BAD_PLUGIN_WRONG_ABI)

  add_library(hm-nvbench-profile-wrong-adapter-plugin SHARED tests/bad_plugin.cpp)
  target_include_directories(hm-nvbench-profile-wrong-adapter-plugin PRIVATE include)
  target_compile_definitions(hm-nvbench-profile-wrong-adapter-plugin PRIVATE HM_NVPROFILE_BAD_PLUGIN_WRONG_ADAPTER)

  add_executable(hm-nvbench-profile-smoke tests/smoke.cpp)
  target_link_libraries(hm-nvbench-profile-smoke PRIVATE hmdemo_nvbench_profile_core)
  target_compile_definitions(hm-nvbench-profile-smoke PRIVATE
    HM_NVPROFILE_MISSING_ENTRY_PLUGIN_PATH="$<TARGET_FILE:hm-nvbench-profile-missing-entry-plugin>"
    HM_NVPROFILE_WRONG_ABI_PLUGIN_PATH="$<TARGET_FILE:hm-nvbench-profile-wrong-abi-plugin>"
    HM_NVPROFILE_WRONG_ADAPTER_PLUGIN_PATH="$<TARGET_FILE:hm-nvbench-profile-wrong-adapter-plugin>"
  )
  add_dependencies(hm-nvbench-profile-smoke
    hm-nvbench-profile-missing-entry-plugin
    hm-nvbench-profile-wrong-abi-plugin
    hm-nvbench-profile-wrong-adapter-plugin
  )
  add_test(NAME hm-nvbench-profile-smoke COMMAND hm-nvbench-profile-smoke)
endif()
