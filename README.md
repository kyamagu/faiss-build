# FAISS Build

This is an experimental repository for building [faiss](https://github.com/facebookresearch/faiss) python package based on [scikit-build-core](https://scikit-build-core.readthedocs.io/en/latest/index.html).

## Build

Clone the github repository with submodules first. Any build backend supporting `scikit-build-core` can build wheels.

```bash
uv build --wheel
```

```bash
pipx run build --wheel
```

You may pass cmake options via command line or environment variable `SKBUILD_CMAKE_DEFINE`. See [the scikit-build-core documentation](https://scikit-build-core.readthedocs.io/en/latest/configuration/index.html#configuring-cmake-arguments-and-defines) for details on how to specify CMake defines.

```bash
export SKBUILD_CMAKE_DEFINE="FAISS_OPT_LEVEL=avx2;FAISS_ENABLE_GPU=ON"
uv build --wheel
```

```bash
uv build --wheel \
    -Ccmake.define.FAISS_OPT_LEVEL=avx2 \
    -Ccmake.define.FAISS_ENABLE_GPU=ON
```

See also the list of supported build-time options in [the upstream documentation](https://github.com/facebookresearch/faiss/blob/main/INSTALL.md#step-1-invoking-cmake).


## Troubleshooting

macOS users might need to set `OpenMP_ROOT`.

```bash
export OpenMP_ROOT=$(brew --prefix)/opt/libomp
```