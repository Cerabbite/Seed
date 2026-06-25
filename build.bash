#!/bin/bash

# Exit immediately if a command fails
set -e

# 1. Get the Git Hash
COMMIT_HASH=$(git rev-parse --short HEAD)
if [[ -n $(git status --porcelain) ]]; then
    COMMIT_HASH="$COMMIT_HASH-di
fi

echo "--- Building Seed (Hash: $COMMIT_HASH) ---"

mkdir -p bin

# 2. Build the project
# -o:speed tells Odin to optimize for performance
# -define:COMMIT_HASH injects our dynamic git hash
# -extra-linker-flags passes the necessary system libraries
odin build seed \
    -out:bin/seed \
    -o:speed \
    -define:COMMIT_HASH="\"$COMMIT_HASH\"" \
    -extra-linker-flags:"-s -w -lGL -lX11 -lpthread -ldl"

echo "--- Build Complete: ./seed ---"

# 3. Size check (optional)
ls -lh seed