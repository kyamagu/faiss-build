#!/usr/bin/env bash

set -eux

# Install system dependencies.
brew install libomp

# Set MACOSX_DEPLOYMENT_TARGET.
MACOS_VERSION=$(sw_vers -productVersion | xargs)
if [ "$MACOS_VERSION" == 13* ]; then
    echo "MACOSX_DEPLOYMENT_TARGET=13.0" >> $GITHUB_ENV
else
    echo "MACOSX_DEPLOYMENT_TARGET=14.0" >> $GITHUB_ENV
fi
