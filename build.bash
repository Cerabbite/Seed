#!/bin/bash

set -e

# Make sure that GLFW is installed correcly for static linking.
GLFW_DEST="seed/lib/libglfw3.a"

if [ ! -f "$GLFW_DEST" ]; then
    echo "--- GLFW library not found, building from source... ---"
    
    mkdir -p seed/lib
    TMP_DIR=$(mktemp -d)
    
    git clone --depth 1 https://github.com/glfw/glfw.git "$TMP_DIR"
    
    mkdir -p "$TMP_DIR/build"
    cd "$TMP_DIR/build"
    
    cmake .. \
        -DCMAKE_C_FLAGS="-fPIC -Os" \
        -DGLFW_BUILD_EXAMPLES=OFF \
        -DGLFW_BUILD_TESTS=OFF \
        -DGLFW_BUILD_DOCS=OFF \
        -DGLFW_INSTALL=OFF
    
    make -j$(nproc)
    
    cp src/libglfw3.a "$OLDPWD/seed/lib/libglfw3.a"
    
    # Cleanup
    cd "$OLDPWD"
    rm -rf "$TMP_DIR"
    echo "--- GLFW built successfully ---"
fi

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