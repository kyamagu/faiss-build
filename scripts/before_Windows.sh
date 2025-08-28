#!/usr/bin/env bash

set -eux

# Function to install OpenBLAS for Windows from https://github.com/OpenMathLib/OpenBLAS/releases
function install_openblas() {
    echo "Installing OpenBLAS for Windows..."
    local OPENBLAS_VERSION="0.3.30"
    local OPENBLAS_URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/v${OPENBLAS_VERSION}/OpenBLAS-${OPENBLAS_VERSION}-$1.zip"
    local ZIP_PATH="$RUNNER_TEMP/OpenBLAS.zip"
    local DEST_PATH="${ProgramFiles:-c:/Program Files}/OpenBLAS"
    curl -sL "$OPENBLAS_URL" -o "$ZIP_PATH"
    mkdir -p "$DEST_PATH"

    # Extract to destination
    powershell.exe -Command "Expand-Archive -Path '$ZIP_PATH' -DestinationPath '$DEST_PATH' -Force"
    powershell.exe -Command "Move-Item '$DEST_PATH/OpenBLAS*/*' '$DEST_PATH/' -Force"
    powershell.exe -Command "Remove-Item '$DEST_PATH/OpenBLAS*' -Recurse"
}

# Install system dependencies
if [[ "$PROCESSOR_IDENTIFIER" == ARM* ]]; then
    # NOTE: PROCESSOR_ARCHITECTURE is incorrectly set to "AMD64" on emulated ARM64 Windows runners.
    install_openblas woa64-dll
else
    vcpkg install openblas:x64-windows
fi