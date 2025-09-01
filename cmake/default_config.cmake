# Top-level default configuration for faiss-build
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
option(FAISS_ENABLE_ROCM "Enable support for ROCm" OFF)
option(FAISS_ENABLE_CUVS "Enable support for cuVS" OFF)
option(FAISS_USE_LTO "Enable Link Time Optimization (LTO)." ON)

set(FAISS_ENABLE_EXTRAS OFF)
set(BUILD_TESTING OFF)
set(FAISS_ENABLE_PYTHON OFF) # We use our own Python build configuration.
set(PYTHON_PACKAGE_NAME
    "faiss"
    CACHE STRING "Python package name, default to faiss")

# SABI options. TODO: Derive the hex value from SKBUILD_SABI_VERSION.
set(PY_LIMITED_API
    "0x03090000"
    CACHE STRING "Py_LIMITED_API macro value")
include(CMakeDependentOption)
cmake_dependent_option(ENABLE_SABI "Enable stable ABI." ON
                       "SKBUILD_SABI_VERSION" OFF)
message(STATUS "Optimization level - ${FAISS_OPT_LEVEL}")
message(STATUS "Stable ABI - ${SKBUILD_SABI_VERSION}")

# Helper to define default build options.
function(configure_default_options)
  set(CMAKE_CXX_STANDARD 17 PARENT_SCOPE)
  set(CMAKE_CXX_STANDARD_REQUIRED ON PARENT_SCOPE)
  set(CMAKE_CXX_EXTENSIONS OFF PARENT_SCOPE)
  message(STATUS "C++ standard - ${CMAKE_CXX_STANDARD}")

  # Set up platform-specific global flags.
  if(APPLE)
    configure_apple_platform()
  elseif(UNIX)
    configure_linux_platform()
  elseif(WIN32)
    configure_win32_platform()
  endif()

  # Use ccache if available.
  find_program(CCACHE_FOUND ccache)
  if(CCACHE_FOUND)
    message(STATUS "ccache enabled")
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  endif()
endfunction()

# Helper to configure Apple platform
function(configure_apple_platform)
  add_compile_options(-Wno-unused-function -Wno-format
                      -Wno-deprecated-declarations)
  add_link_options(-dead_strip)
  # Set OpenMP_ROOT from Homebrew.
  if(NOT DEFINED OpenMP_ROOT)
    find_program(HOMEBREW_FOUND brew)
    if(HOMEBREW_FOUND)
      execute_process(
        COMMAND brew --prefix libomp
        OUTPUT_VARIABLE HOMEBREW_LIBOMP_PREFIX
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      set(OpenMP_ROOT
          "${HOMEBREW_LIBOMP_PREFIX}"
          CACHE PATH "OpenMP root from Homebrew")
    endif()
  endif()
  # Set MACOSX_DEPLOYMENT_TARGET.
  if(NOT DEFINED ENV{MACOSX_DEPLOYMENT_TARGET})
    execute_process(COMMAND sw_vers -productVersion
                    OUTPUT_VARIABLE MACOSX_VERSION
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(${MACOSX_VERSION} VERSION_LESS "10.14")
      set(ENV{MACOSX_DEPLOYMENT_TARGET} 10.13)
    else()
      set(ENV{MACOSX_DEPLOYMENT_TARGET} 10.14)
    endif()
  endif()
  message(STATUS "MACOSX_DEPLOYMENT_TARGET - $ENV{MACOSX_DEPLOYMENT_TARGET}")
endfunction()

# Helper to configure Win32 platform
function(configure_win32_platform)
  # A few of warning suppressions for Windows.
  if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    add_compile_options(/wd4101 /wd4267 /wd4477)
    add_link_options(/ignore:4217)
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    add_compile_options(-Wno-unused-function -Wno-format
                        -Wno-deprecated-declarations)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    add_link_options(/ignore:4217)
  endif()
endfunction()

# Helper to configure Linux platform
function(configure_linux_platform)
  if(${FAISS_ENABLE_GPU} AND NOT ${FAISS_ENABLE_ROCM})
    configure_cuda_flags()
  endif()
  # TODO: Disable the following for CUDA objects.
  add_compile_options(-fdata-sections -ffunction-sections)
  add_link_options(-Wl,--gc-sections)
endfunction()

# Helper to configure default CUDA setup.
function(configure_cuda_flags)
  find_package(CUDAToolkit REQUIRED)
  if(NOT DEFINED ENV{CUDACXX})
    # Enabling CUDA language support requires nvcc available. Here, we use
    # FindCUDAToolkit to detect nvcc executable.
    set(ENV{CUDACXX} ${CUDAToolkit_NVCC_EXECUTABLE})
  endif()
  # Set default CUDA architecture to all-major.
  if(NOT DEFINED ENV{CUDAARCHS})
    set(ENV{CUDAARCHS} all-major)
  endif()
  if(NOT DEFINED ENV{CUDAFLAGS})
    set(ENV{CUDAFLAGS} -Wno-deprecated-gpu-targets)
  endif()
  # Enable CUDA language support.
  enable_language(CUDA)
endfunction()
