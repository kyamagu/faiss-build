cmake_minimum_required(VERSION 3.15...3.26)
project(${SKBUILD_PROJECT_NAME} LANGUAGES CXX)

set(PYTHON_PACKAGE_NAME "faiss")

# Build-time options.
option(FAISS_OPT_LEVEL "Optimization level, one of <generic|avx2|avx512|avx512_spr|sve>" "generic")
option(FAISS_ENABLE_GPU "Enable support for GPU indexes." OFF)

# Import symbols from the third-party/faiss directory.
set(BUILD_TESTING OFF)
add_subdirectory(third-party/faiss EXCLUDE_FROM_ALL)

# Set and install the targets based on the optimization level.
function(install_swig_target target)
    set_target_properties(${target} PROPERTIES EXCLUDE_FROM_ALL FALSE)
    install(TARGETS ${target} DESTINATION ${PYTHON_PACKAGE_NAME})
    get_property(support_files TARGET ${target} PROPERTY SWIG_SUPPORT_FILES)
    install(FILES ${support_files} DESTINATION ${PYTHON_PACKAGE_NAME})
endfunction()

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