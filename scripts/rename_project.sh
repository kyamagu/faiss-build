#!/usr/bin/env bash

set -eux

sed -i '' "s/^name = \"faiss-cpu\"/name = \"${1}\"/" pyproject.toml