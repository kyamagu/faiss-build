# Top-level default configuration for faiss-build

# Optimization levels; e.g., "generic;avx2"
set(FAISS_OPT_LEVELS
    "generic"
    CACHE
      STRING
      "Optimization level, semicolon-separated string of <generic|avx2|avx512|avx512_spr|sve>."
)
if(DEFINED ENV{FAISS_OPT_LEVELS})
  set(FAISS_OPT_LEVELS
      $ENV{FAISS_OPT_LEVELS}
      CACHE STRING "Optimization level." FORCE)
endif()
set(FAISS_OPT_LEVELS_VALUES "generic;avx2;avx512;avx512_spr;sve")
foreach(level IN LISTS FAISS_OPT_LEVELS)
  if(NOT level IN_LIST FAISS_OPT_LEVELS_VALUES)
    message(FATAL_ERROR "Invalid FAISS_OPT_LEVELS value: ${level}.\
        Supported values are combination of: ${FAISS_OPT_LEVELS_VALUES}")
  endif()
endforeach()
if(NOT FAISS_OPT_LEVELS)
  message(FATAL_ERROR "FAISS_OPT_LEVELS is empty.")
endif()
message(STATUS "Faiss optimization levels - ${FAISS_OPT_LEVELS}")

# GPU supports.
set(FAISS_GPU_SUPPORT
    OFF
    CACHE STRING "GPU support, one of <OFF|CUDA|CUVS|ROCM>.")
if(DEFINED ENV{FAISS_GPU_SUPPORT})
  set(FAISS_GPU_SUPPORT
      $ENV{FAISS_GPU_SUPPORT}
      CACHE STRING "GPU support, one of <OFF|CUDA|CUVS|ROCM>." FORCE)
endif()
set(FAISS_GPU_SUPPORT_VALUES "OFF;CUDA;CUVS;ROCM")
set_property(CACHE FAISS_GPU_SUPPORT PROPERTY STRINGS FAISS_GPU_SUPPORT_VALUES)
if(NOT FAISS_GPU_SUPPORT IN_LIST FAISS_GPU_SUPPORT_VALUES)
  message(FATAL_ERROR "Invalid FAISS_GPU_SUPPORT value: ${FAISS_GPU_SUPPORT}.\
  Supported values are: ${FAISS_GPU_SUPPORT_VALUES}")
endif()

# Expand variables for GPU support in the faiss cmake config.
if(FAISS_GPU_SUPPORT)
  set(FAISS_ENABLE_GPU ON)
  if("CUDA" IN_LIST FAISS_GPU_SUPPORT)
    set(FAISS_ENABLE_CUDA ON) # This is not a faiss cmake config variable.
  elseif("CUVS" IN_LIST FAISS_GPU_SUPPORT)
    set(FAISS_ENABLE_CUDA ON)
    set(FAISS_ENABLE_CUVS ON)
  elseif("ROCM" IN_LIST FAISS_GPU_SUPPORT)
    set(FAISS_ENABLE_ROCM ON)
  endif()
else()
  set(FAISS_ENABLE_GPU OFF)
endif()
message(STATUS "Faiss GPU support - ${FAISS_GPU_SUPPORT}")

# LTO option.
option(FAISS_USE_LTO "Enable Link Time Optimization (LTO)." ON)

# Python package name.
set(PYTHON_PACKAGE_NAME
    "faiss"
    CACHE STRING "Python package name, default to faiss")

# Py_LIMITED_API value, default to <0x03090000>. TODO: Derive the hex value from
# SKBUILD_SABI_VERSION.
set(PY_LIMITED_API
    "0x03090000"
    CACHE STRING "Py_LIMITED_API macro value")

# Default overrides for building Python bindings.
set(FAISS_ENABLE_EXTRAS OFF)
set(BUILD_TESTING OFF)
set(FAISS_ENABLE_PYTHON OFF) # We use our own Python build configuration.
if(SKBUILD_SABI_VERSION STREQUAL "")
  set(ENABLE_SABI OFF)
  message(STATUS "Stable ABI - OFF")
else()
  set(ENABLE_SABI ON)
  message(STATUS "Stable ABI - ${SKBUILD_SABI_VERSION}")
endif()

# Helper to define default build options.
function(configure_default_options)
  set(CMAKE_CXX_STANDARD
      17
      PARENT_SCOPE)
  set(CMAKE_CXX_STANDARD_REQUIRED
      ON
      PARENT_SCOPE)
  set(CMAKE_CXX_EXTENSIONS
      OFF
      PARENT_SCOPE)

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
          HOMEBREW_LIBOMP_PREFIX
          CACHE PATH "OpenMP root from Homebrew")
    endif()
  endif()
  # Set MACOSX_DEPLOYMENT_TARGET. NOTE: This is a workaround for the
  # compatibility with libomp on Homebrew. For C++17 compatibility, the minimum
  # required version is 10.13.
  if(NOT DEFINED ENV{MACOSX_DEPLOYMENT_TARGET})
    execute_process(
      COMMAND sw_vers -productVersion
      OUTPUT_VARIABLE MACOSX_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(${MACOSX_VERSION} VERSION_LESS "14.0")
      set(ENV{MACOSX_DEPLOYMENT_TARGET} 13.0)
    else()
      set(ENV{MACOSX_DEPLOYMENT_TARGET} 14.0)
    endif()
  endif()
  message(STATUS "macOS deployment target - $ENV{MACOSX_DEPLOYMENT_TARGET}")
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
  if(FAISS_ENABLE_CUDA)
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
