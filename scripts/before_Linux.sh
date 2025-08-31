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
    # TODO: Detect distro and arch here.
    distro=rhel8
    arch=x86_64
    dnf config-manager --set-enabled powertools
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${distro}/${arch}/cuda-${distro}.repo
    dnf install -y cuda-toolkit
fi