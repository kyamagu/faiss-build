#!/usr/bin/env bash

set -eux

# Install system dependencies
if command -v apk &> /dev/null; then
    apk add --no-cache openblas-dev swig
elif command -v dnf &> /dev/null; then
    dnf install -y openblas-devel openblas-static swig
elif command -v apt &> /dev/null; then
    apt install -y libopenblas-dev swig
elif command -v yum &> /dev/null; then
    yum install -y openblas-devel openblas-static swig
else
    echo "Unsupported package manager. Please install dependencies manually."
    exit 1
fi