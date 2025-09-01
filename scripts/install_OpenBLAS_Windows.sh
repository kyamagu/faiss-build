#!/usr/bin/env bash

set -eux

# Function to install OpenBLAS for Windows from https://github.com/OpenMathLib/OpenBLAS/releases
function install_openblas() {
    echo "Installing OpenBLAS for Windows..."
    local OPENBLAS_VERSION="0.3.30"
    local OPENBLAS_URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/v${OPENBLAS_VERSION}/OpenBLAS-${OPENBLAS_VERSION}-$1.zip"
    local ZIP_PATH="$RUNNER_TEMP/OpenBLAS.zip"
    local INSTALL_DIR="${OPENBLAS_DIR:-c:/Program Files/OpenBLAS}"
    curl -sL "$OPENBLAS_URL" -o "$ZIP_PATH"
    mkdir -p "$INSTALL_DIR"

    # Extract to destination
    powershell.exe -Command "Expand-Archive -Path '$ZIP_PATH' -DestinationPath '$INSTALL_DIR' -Force"
    powershell.exe -Command "Move-Item '$INSTALL_DIR/OpenBLAS*/*' '$INSTALL_DIR/' -Force"
    powershell.exe -Command "Remove-Item '$INSTALL_DIR/OpenBLAS*' -Recurse"

    # Set GITHUB_ENV
    echo "PATH=${PATH:-}:/c/Program Files/OpenBLAS/bin" >> $GITHUB_ENV
    echo "CPATH=${CPATH:-}:/c/Program Files/OpenBLAS/include" >> $GITHUB_ENV
    echo "LIB=${LIB:-}:/c/Program Files/OpenBLAS/lib" >> $GITHUB_ENV
}

# Install system dependencies
if [[ "$PROCESSOR_IDENTIFIER" == ARM* ]]; then
    # NOTE: PROCESSOR_ARCHITECTURE is incorrectly set to "AMD64" on emulated ARM64 Windows runners.
    install_openblas woa64-dll
else
    install_openblas x64
fi