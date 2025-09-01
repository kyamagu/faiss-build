#!/usr/bin/env bash

set -eux

# OpenBLAS installation
function install_openblas() {
    if command -v apk &> /dev/null; then
        apk add --no-cache openblas-dev
    elif command -v dnf &> /dev/null; then
        dnf install -y openblas-devel
    elif command -v apt &> /dev/null; then
        apt install -y libopenblas-dev
    elif command -v yum &> /dev/null; then
        yum install -y openblas-devel
    else
        echo "Unsupported package manager. Please install OpenBLAS manually."
    fi
}

# CUDA installation
function install_cuda() {
    ARCH=$(uname -m)
    CUDA_VERSION=${CUDA_VERSION:-12.8}
    CUDA_PACKAGE_VERSION=${CUDA_VERSION//./-}
    if command -v apk &> /dev/null; then
        DISTRO=${DISTRO:-alpine}
        echo "CUDA installation on Alpine is not supported yet."
        exit 1
    elif command -v dnf &> /dev/null; then
        # TODO: Detect DISTRO via /etc/*-release.
        DISTRO=${DISTRO:-rhel8}
        dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-${DISTRO}.repo
        dnf install -y \
            cuda-nvcc-${CUDA_PACKAGE_VERSION} \
            cuda-profiler-api-${CUDA_PACKAGE_VERSION} \
            cuda-cudart-devel-${CUDA_PACKAGE_VERSION} \
            libcublas-devel-${CUDA_PACKAGE_VERSION} \
            libcurand-devel-${CUDA_PACKAGE_VERSION}
    elif command -v apt &> /dev/null; then
        DISTRO=${DISTRO:-ubuntu2404}
        wget https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-keyring_1.1-1_all.deb
        dpkg -i cuda-keyring_1.1-1_all.deb
        apt update && apt install -y \
            cuda-nvcc-${CUDA_PACKAGE_VERSION} \
            cuda-profiler-api-${CUDA_PACKAGE_VERSION} \
            cuda-cudart-dev-${CUDA_PACKAGE_VERSION} \
            libcublas-dev-${CUDA_PACKAGE_VERSION} \
            libcurand-dev-${CUDA_PACKAGE_VERSION}
    else
        echo "Unsupported package manager. Please install CUDA Toolkit manually."
    fi
}

install_openblas
if [ "${FAISS_ENABLE_GPU:-OFF}" = "ON" ]; then
    install_cuda
fi