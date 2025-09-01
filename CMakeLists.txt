cmake_minimum_required(VERSION 3.24...4.0)

# Guard for standalone CMake build instead of scikit-build-core.
if(NOT "${SKBUILD}" STREQUAL "2")
  # TODO: extract information from pyproject.toml
  message(STATUS "Standalone CMake build detected.")
  set(SKBUILD_PROJECT_NAME
      "faiss-cpu"
      CACHE STRING "Project name")
  set(SKBUILD_PROJECT_VERSION
      "1.12.0"
      CACHE STRING "Project version")
  set(SKBUILD_SABI_VERSION
      ""
      CACHE STRING "SABI version")
  set(SKBUILD_SOABI
      "abi3"
      CACHE STRING "SOABI tag")
endif()

# Project configuration.
project(
  ${SKBUILD_PROJECT_NAME}
  VERSION ${SKBUILD_PROJECT_VERSION}
  DESCRIPTION "Python bindings for faiss."
  LANGUAGES CXX)

# Configuration options that override faiss C++ default.
set(FAISS_OPT_LEVEL
    "generic"
    CACHE STRING
          "Optimization level, one of <generic|avx2|avx512|avx512_spr|sve>")
if(DEFINED ENV{FAISS_OPT_LEVEL})
  set(FAISS_OPT_LEVEL
      $ENV{FAISS_OPT_LEVEL}
      CACHE STRING "Optimization level." FORCE)
endif()

option(FAISS_ENABLE_GPU "Enable support for GPU indexes." OFF)
if(DEFINED ENV{FAISS_ENABLE_GPU})
  set(FAISS_ENABLE_GPU
      $ENV{FAISS_ENABLE_GPU}
      CACHE BOOL "Enable support for GPU indexes." FORCE)
endif()

option(FAISS_USE_LTO "Enable Link Time Optimization (LTO)." ON)
set(FAISS_ENABLE_EXTRAS OFF)
set(BUILD_TESTING OFF)
set(FAISS_ENABLE_PYTHON OFF) # We use our own Python build configuration.
set(PYTHON_PACKAGE_NAME
    "faiss"
    CACHE STRING "Python package name, default to faiss")
# TODO: Derive the hex value from SKBUILD_SABI_VERSION.
set(PY_LIMITED_API
    "0x03090000"
    CACHE STRING "Py_LIMITED_API macro value")

# Print out the SABI configuration.
include(CMakeDependentOption)
cmake_dependent_option(ENABLE_SABI "Enable stable ABI." ON
                       "SKBUILD_SABI_VERSION" OFF)
message(STATUS "Optimization level - ${FAISS_OPT_LEVEL}")
message(STATUS "Stable ABI - ${SKBUILD_SABI_VERSION}")

# Global build configuration when this project is the top-level project.
if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)

  # Set up platform-specific global flags.
  if(APPLE)
    add_compile_options(-Wno-unused-function -Wno-format
                        -Wno-deprecated-declarations)
    add_link_options(-dead_strip)
  elseif(UNIX)
    add_compile_options(-fdata-sections -ffunction-sections)
    add_link_options(-Wl,--gc-sections)
    if(${FAISS_ENABLE_GPU})
      if(${FAISS_ENABLE_ROCM})

      else()
        find_package(CUDAToolkit REQUIRED)
        if(NOT DEFINED CMAKE_CUDA_COMPILER)
          # Enabling CUDA language support requires nvcc available. Here, we use
          # FindCUDAToolkit to detect nvcc executable.
          set(CMAKE_CUDA_COMPILER ${CUDAToolkit_NVCC_EXECUTABLE})
        endif()
        # Set default CUDA architecture to all-major.
        if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
          set(CMAKE_CUDA_ARCHITECTURES all-major)
        endif()
        # Suppress deprecation warnings by default as the library targets many
        # architectures.
        if(NOT DEFINED CMAKE_CUDA_FLAGS)
          set(CMAKE_CUDA_FLAGS -Wno-deprecated-gpu-targets)
        endif()
      endif()
    endif()
  elseif(WIN32)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
      add_compile_options(/wd4101 /wd4267 /wd4477)
      add_link_options(/ignore:4217)
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
      add_compile_options(-Wno-unused-function -Wno-format
                          -Wno-deprecated-declarations)
      add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
      add_link_options(/ignore:4217)
    endif()
  endif()

  # Use ccache if available.
  find_program(CCACHE_FOUND ccache)
  if(CCACHE_FOUND)
    message(STATUS "ccache enabled")
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  endif()
endif()

# Import targets from the third-party/faiss directory.
add_subdirectory(third-party/faiss EXCLUDE_FROM_ALL)

# Python bindings.
add_subdirectory(python)
