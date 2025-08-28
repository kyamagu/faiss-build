cmake_minimum_required(VERSION 3.15...3.26)
project(${SKBUILD_PROJECT_NAME} LANGUAGES CXX)

set(PYTHON_PACKAGE_NAME "faiss")

# Build-time options.
option(FAISS_OPT_LEVEL "Optimization level, one of <generic|avx2|avx512|avx512_spr|sve>" "generic")
option(FAISS_ENABLE_GPU "Enable support for GPU indexes." OFF)
option(FAISS_USE_LTO "Enable Link Time Optimization (LTO)." ON)
set(FAISS_ENABLE_EXTRAS OFF)
set(BUILD_TESTING OFF)

# Set up platform-specific flags.
if(APPLE)
    add_compile_options(-Wno-deprecated-declarations)
    add_link_options(-dead_strip)
elseif(UNIX)
    add_compile_options(-fdata-sections -ffunction-sections)
    add_link_options(-Wl,--gc-sections)
elseif(WIN32)
    # /wd4101 unreferenced local variable
    # /wd4267 conversion from 'size_t' to 'type', possible loss of data
    # /wd4477 printf formatting
    # /MD Bugfix: https://bugs.python.org/issue38597
    add_compile_options(/Zc:inline /wd4101 /wd4267 /wd4477 /MD)
    add_link_options(/OPT:ICF /OPT:REF /ignore:4286)
endif()

# Use ccache if available.
find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
   set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
endif()

# Import symbols from the third-party/faiss directory.
add_subdirectory(third-party/faiss EXCLUDE_FROM_ALL)

# Stable ABI configuration.
if(NOT "${SKBUILD_SABI_VERSION}" STREQUAL "")
    find_package(Python REQUIRED COMPONENTS ${SKBUILD_SABI_COMPONENT})
endif()

# Helper to install SWIG targets.
function(install_swig_target name)
    # Enable the target.
    set_target_properties(${name} PROPERTIES EXCLUDE_FROM_ALL FALSE)

    # Stable ABI configuration.
    if(NOT "${SKBUILD_SABI_VERSION}" STREQUAL "")
        target_compile_definitions(${name} PRIVATE Py_LIMITED_API=0x03080000)
        string(REPLACE "swig" "" libname ${name})
        set_property(
            TARGET ${name} PROPERTY
            LINK_LIBRARY_OVERRIDE Python::NumPy;Python::SABIModule,OpenMP::OpenMP_CXX,${libname},faiss_python_callbacks
        )
        if(WIN32)
            set_target_properties(${name} PROPERTIES SUFFIX ".${SKBUILD_SOABI}.pyd")
        else()
            set_target_properties(${name} PROPERTIES SUFFIX ".${SKBUILD_SOABI}${CMAKE_SHARED_MODULE_SUFFIX}")
        endif()
    endif()

    # Install the SWIG-generated files and the built shared library.
    get_property(support_files TARGET ${name} PROPERTY SWIG_SUPPORT_FILES)
    install(TARGETS ${name} DESTINATION ${PYTHON_PACKAGE_NAME})
    install(FILES ${support_files} DESTINATION ${PYTHON_PACKAGE_NAME})
endfunction()

# Install the targets based on the optimization level.
install_swig_target(swigfaiss)
if(FAISS_OPT_LEVEL MATCHES "^(avx2|avx512|avx512_spr)$")
    install_swig_target(swigfaiss_avx2)
endif()
if(FAISS_OPT_LEVEL MATCHES "^(avx512|avx512_spr)$")
    install_swig_target(swigfaiss_avx512)
endif()
if(FAISS_OPT_LEVEL STREQUAL "avx512_spr")
    install_swig_target(swigfaiss_avx512_spr)
endif()
if(FAISS_OPT_LEVEL STREQUAL "sve")
    install_swig_target(swigfaiss_sve)
endif()

# Install Python source files.
install(
    DIRECTORY third-party/faiss/faiss/python/
    DESTINATION ${PYTHON_PACKAGE_NAME}
    FILES_MATCHING PATTERN "*.py" PATTERN "setup.py" EXCLUDE
)
install(
    DIRECTORY third-party/faiss/contrib
    DESTINATION ${PYTHON_PACKAGE_NAME}
    FILES_MATCHING PATTERN "*.py"
)