# Find requirements.
find_package(SWIG REQUIRED COMPONENTS python)
if(${ENABLE_SABI})
  find_package(Python REQUIRED COMPONENTS Interpreter Development.SABIModule
                                          NumPy)
else()
  find_package(Python REQUIRED COMPONENTS Interpreter Development.Module NumPy)
endif()
find_package(OpenMP REQUIRED)

# Find SWIG and set up the build configuration.
include(${SWIG_USE_FILE})
set(UseSWIG_TARGET_NAME_PREFERENCE STANDARD)
set(SWIG_SOURCE_FILE_EXTENSIONS swig)

# Helper to set up Stable ABI properties.
function(configure_sabi_properties target)
  if(${ENABLE_SABI})
    target_compile_definitions(${target}
                               PRIVATE Py_LIMITED_API=${PY_LIMITED_API})
    if(WIN32)
      if("${SKBUILD_SOABI}" STREQUAL "")
        set(SKBUILD_SOABI "abi3"
        )# https://github.com/scikit-build/scikit-build-core/issues/690
      endif()
      set_target_properties(${target} PROPERTIES SUFFIX ".${SKBUILD_SOABI}.pyd")
    else()
      set_target_properties(
        ${target} PROPERTIES SUFFIX
                             ".${SKBUILD_SOABI}${CMAKE_SHARED_MODULE_SUFFIX}")
    endif()
  else()
    if(WIN32)
      set_target_properties(${target} PROPERTIES SUFFIX ".pyd")
    else()
      set_target_properties(${target}
                            PROPERTIES SUFFIX "${CMAKE_SHARED_MODULE_SUFFIX}")
    endif()
  endif()
endfunction()

# Helper to set up GPU-related properties.
function(configure_gpu_properties target)
  if(${FAISS_ENABLE_GPU})
    target_compile_definitions(${target} PRIVATE FAISS_ENABLE_GPU)
    if(${FAISS_ENABLE_ROCM})
      target_link_libraries(${target} PRIVATE hip::host)
    else()
      target_link_libraries(${target} PRIVATE CUDA::cudart)
      if(${FAISS_ENABLE_CUVS})
        target_link_libraries(${target} PRIVATE cuvs::cuvs)
      endif()
    endif()
  endif()
endfunction()

# Helper to build and install faiss SWIG extensions.
function(configure_extension suffix)
  # Configure swigfaiss extension.
  set(target "swigfaiss${suffix}")
  set(swig_source_file
      ${CMAKE_CURRENT_SOURCE_DIR}/../third-party/faiss/faiss/python/swigfaiss.swig
  )
  set_source_files_properties(
    ${swig_source_file}
    PROPERTIES
      CPLUSPLUS ON
      USE_TARGET_INCLUDE_DIRECTORIES TRUE
      DEPENDS
      "${FAISS_HEADERS};$<$<BOOL:${FAISS_ENABLE_GPU}>:${FAISS_GPU_HEADERS}>"
      COMPILE_OPTIONS -doxygen
      SWIG_MODULE_NAME ${target})
  swig_add_library(
    ${target}
    TYPE SHARED
    LANGUAGE python
    SOURCES ${swig_source_file})

  # Set up platform-specific flags.
  if(${WIN32})
    set_property(TARGET ${target} PROPERTY SWIG_COMPILE_DEFINITIONS SWIGWIN)
    target_compile_options(${target} PRIVATE /bigobj)
  elseif(${APPLE})
    # Nothing here.
  else()
    set_property(TARGET ${target} PROPERTY SWIG_COMPILE_DEFINITIONS
                                           SWIGWORDSIZE64)
    configure_gpu_properties(${target})
  endif()

  # Set up Stable ABI properties.
  configure_sabi_properties(${target})
  # Linker configuration
  target_link_libraries(
    ${target} PRIVATE "faiss${suffix}" OpenMP::OpenMP_CXX Python::NumPy faiss_python_callbacks)
  if(${ENABLE_SABI})
    target_link_libraries(${target} PRIVATE Python::SABIModule)
  else()
    target_link_libraries(${target} PRIVATE Python::Module)
  endif()

  # Install the SWIG-generated files and the built shared library.
  get_property(
    support_files
    TARGET ${target}
    PROPERTY SWIG_SUPPORT_FILES)
  install(TARGETS ${target} DESTINATION ${PYTHON_PACKAGE_NAME})
  install(FILES ${support_files} DESTINATION ${PYTHON_PACKAGE_NAME})
endfunction()

# Build the callback lib.
add_library(
  faiss_python_callbacks STATIC EXCLUDE_FROM_ALL
  ${CMAKE_CURRENT_SOURCE_DIR}/../third-party/faiss/faiss/python/python_callbacks.cpp
)
set_property(TARGET faiss_python_callbacks PROPERTY POSITION_INDEPENDENT_CODE
                                                    ON)
target_include_directories(
  faiss_python_callbacks
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../third-party/faiss/)
target_include_directories(faiss_python_callbacks
                           PRIVATE ${Python_INCLUDE_DIRS})
if(${ENABLE_SOABI})
  target_compile_definitions(faiss_python_callbacks
                             PRIVATE Py_LIMITED_API=${PY_LIMITED_API})
endif()

# Build extensions based on the optimization level.
configure_extension("")
if(FAISS_OPT_LEVEL MATCHES "^(avx2|avx512|avx512_spr)$")
  configure_extension(_avx2)
endif()
if(FAISS_OPT_LEVEL MATCHES "^(avx512|avx512_spr)$")
  configure_extension(_avx512)
endif()
if(FAISS_OPT_LEVEL STREQUAL "avx512_spr")
  configure_extension(_avx512_spr)
endif()
if(FAISS_OPT_LEVEL STREQUAL "sve")
  configure_extension(_sve)
endif()

# Package Python source files.
install(
  DIRECTORY ../third-party/faiss/faiss/python/
  DESTINATION ${PYTHON_PACKAGE_NAME}
  FILES_MATCHING
  PATTERN "*.py"
  PATTERN "setup.py" EXCLUDE)
install(
  DIRECTORY ../third-party/faiss/contrib
  DESTINATION ${PYTHON_PACKAGE_NAME}
  FILES_MATCHING
  PATTERN "*.py")
