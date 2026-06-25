#!/bin/bash

set -e

COMMIT_HASH=$(git rev-parse --short HEAD)
if [[ -n $(git status --porcelain) ]]; then
    COMMIT_HASH=$COMMIT_HASH-dirty
fi

echo "--- Building Seed (Hash: $COMMIT_HASH) ---"

mkdir -p bin

odin build seed \
    -out:bin/seed \
    -o:speed \
    -define:COMMIT_HASH="$COMMIT_HASH" \
    -extra-linker-flags:"-s -w -lGL -lX11 -lpthread -ldl"

echo "--- Build Complete: ./seed ---"

ls -lh seed