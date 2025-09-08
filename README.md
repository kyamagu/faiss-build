# FAISS Build

This is an experimental repository for building [faiss](https://github.com/facebookresearch/faiss) python package based on [scikit-build-core](https://scikit-build-core.readthedocs.io/en/latest/index.html).

## Build

Install OpenBLAS on Linux and Windows environment. Then, clone the github repository with submodules.

```bash
git clone --recursive https://github.com/kyamagu/faiss-build.git
```

At the root of the project directory, any build backend supporting `scikit-build-core` can build wheels.

```bash
pipx run build --wheel
```

```bash
python -m build --wheel
```

```bash
uv build --wheel
```

### Customizing build options

You can set environment variables to customize the build options.

```bash
export FAISS_OPT_LEVELS=avx2
export FAISS_GPU_SUPPORT=CUDA
pipx run build --wheel
```

Alternatively, you may pass cmake options via command line or environment variable `SKBUILD_CMAKE_DEFINE`. See [the scikit-build-core documentation](https://scikit-build-core.readthedocs.io/en/latest/configuration/index.html#configuring-cmake-arguments-and-defines) for details on how to specify CMake defines.

```bash
pipx run build --wheel \
    -Ccmake.define.FAISS_OPT_LEVELS=avx2 \
    -Ccmake.define.FAISS_GPU_SUPPORT=CUDA
```

The following options are available for configuration.

- `FAISS_OPT_LEVELS`: Optimization levels. You may set a semicolon-separated list of values from `<generic|avx2|avx512|avx512_spr|sve>`. For example, setting `generic,avx2` will include both `generic` and `avx2` binary extensions in the resulting wheel. This option offers more flexibility than the upstream config variable `FAISS_OPT_LEVEL` which cannot specify arbitrary combinations.
- `FAISS_GPU_SUPPORT`: GPU support. You may set a value from `<OFF|CUDA|CUVS|ROCM>`. For example, setting `CUDA` will enable CUDA support. You will need a CUDA toolkit installed on the system.
- `FAISS_ENABLE_MKL`: Intel MKL support. Default is `OFF`. Setting `FAISS_ENABLE_MKL=ON` links Intel oneAPI Math Kernel Library instead of OpenBLAS on Linux. You will need to install MKL before building a wheel.
- `FAISS_USE_LTO`: Enable link time optimization. Default is `ON`. Set `FAISS_USE_LTO=OFF` to disable.

See also the list of supported build-time options in [the upstream documentation](https://github.com/facebookresearch/faiss/blob/main/INSTALL.md#step-1-invoking-cmake). Do not directly set `FAISS_OPT_LEVEL` and `FAISS_ENABLE_GPU` when building a wheel via this project, as that will confuse the build process.