#!/usr/bin/env bash

set -eux

# Install system dependencies
if command -v apk &> /dev/null; then
    apk add --no-cache openblas-dev
elif command -v dnf &> /dev/null; then
    dnf install -y openblas-devel
elif command -v apt &> /dev/null; then
    apt install -y libopenblas-dev
elif command -v yum &> /dev/null; then
    yum install -y openblas-devel
else
    echo "Unsupported package manager. Please install dependencies manually."
    exit 1
fi

# CUDA installation
if command -v dnf &> /dev/null; then
    # TODO: Detect DISTRO and ARCH here.
    DISTRO=rhel8
    ARCH=x86_64
    CUDA_VERSION=${CUDA_VERSION:-12.8}
    CUDA_PACKAGE_VERSION=${CUDA_VERSION//./-}
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-${DISTRO}.repo
    dnf install -y \
        cuda-nvcc-${CUDA_PACKAGE_VERSION} \
        cuda-nvprof-${CUDA_PACKAGE_VERSION} \
        cuda-cudart-devel-${CUDA_PACKAGE_VERSION} \
        libcublas-devel-${CUDA_PACKAGE_VERSION}

    # Set path
    ln -s cuda-${CUDA_VERSION} /usr/local/cuda && \
        echo "/usr/local/cuda/lib64" >> /etc/ld.so.conf.d/cuda.conf && \
        echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
        echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
        ldconfig
fi