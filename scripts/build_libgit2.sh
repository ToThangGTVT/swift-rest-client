#!/bin/bash
#
# Builds a self-contained static libgit2 and wraps it in an XCFramework that
# SwiftPM can link. The app is sandboxed, so it cannot shell out to /usr/bin/git;
# every Git operation goes through this library instead.
#
# The result lands in Vendor/libgit2.xcframework and is gitignored — run this
# once after cloning (build_app.sh does it automatically).
#
set -euo pipefail

LIBGIT2_VERSION="${LIBGIT2_VERSION:-1.9.7}"
DEPLOYMENT_TARGET="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
WORK_DIR="$VENDOR_DIR/.build"
SRC_DIR="$WORK_DIR/libgit2-$LIBGIT2_VERSION"
XCFRAMEWORK="$VENDOR_DIR/libgit2.xcframework"
STAMP="$WORK_DIR/.stamp-$LIBGIT2_VERSION"

if [ -d "$XCFRAMEWORK" ] && [ -f "$STAMP" ] && [ "${FORCE_REBUILD:-0}" != "1" ]; then
    echo "==> libgit2 $LIBGIT2_VERSION already built at $XCFRAMEWORK (FORCE_REBUILD=1 to rebuild)"
    exit 0
fi

command -v cmake >/dev/null || { echo "error: cmake is required (brew install cmake)"; exit 1; }

mkdir -p "$WORK_DIR"

# --- Fetch source -----------------------------------------------------------
if [ ! -d "$SRC_DIR" ]; then
    TARBALL="$WORK_DIR/libgit2-$LIBGIT2_VERSION.tar.gz"
    echo "==> Downloading libgit2 $LIBGIT2_VERSION"
    curl -fsSL -o "$TARBALL" \
        "https://github.com/libgit2/libgit2/archive/refs/tags/v$LIBGIT2_VERSION.tar.gz"
    tar -xzf "$TARBALL" -C "$WORK_DIR"
    rm -f "$TARBALL"
fi

# --- Build one slice per architecture ---------------------------------------
# CMake feature probing is per-architecture, so the arches are configured
# separately and lipo'd together afterwards rather than built as one fat pass.
build_arch() {
    local arch="$1"
    local build_dir="$WORK_DIR/build-$arch"
    local install_dir="$WORK_DIR/install-$arch"

    echo "==> Configuring libgit2 for $arch"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cmake -S "$SRC_DIR" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DCMAKE_INSTALL_PREFIX="$install_dir" \
        -DCMAKE_C_FLAGS="-Wno-deprecated-declarations" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_CLI=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_FUZZERS=OFF \
        -DUSE_HTTPS=SecureTransport \
        -DUSE_SHA1=CollisionDetection \
        -DUSE_SSH=OFF \
        -DUSE_BUNDLED_ZLIB=ON \
        -DUSE_ICONV=ON \
        -DREGEX_BACKEND=regcomp_l \
        > "$build_dir/configure.log" 2>&1 || { tail -40 "$build_dir/configure.log"; exit 1; }

    echo "==> Building libgit2 for $arch"
    cmake --build "$build_dir" --target install --parallel "$(sysctl -n hw.ncpu)" \
        > "$build_dir/build.log" 2>&1 || { tail -40 "$build_dir/build.log"; exit 1; }
}

build_arch arm64
build_arch x86_64

# --- Merge into a universal static library ----------------------------------
UNIVERSAL_DIR="$WORK_DIR/universal"
rm -rf "$UNIVERSAL_DIR"
mkdir -p "$UNIVERSAL_DIR"

lipo -create \
    "$WORK_DIR/install-arm64/lib/libgit2.a" \
    "$WORK_DIR/install-x86_64/lib/libgit2.a" \
    -output "$UNIVERSAL_DIR/libgit2.a"

# Headers are architecture independent, so either install tree will do.
cp -R "$WORK_DIR/install-arm64/include" "$UNIVERSAL_DIR/include"

# Clang needs a module map to expose the C API to Swift as `import Clibgit2`.
cat > "$UNIVERSAL_DIR/include/module.modulemap" <<'MODULEMAP'
module Clibgit2 [system] {
    header "git2.h"
    // Not reachable from git2.h, but needed so callbacks can report their own
    // failure reason back to libgit2.
    header "git2/sys/errors.h"
    export *
}
MODULEMAP

# --- Package as an XCFramework ----------------------------------------------
echo "==> Creating $XCFRAMEWORK"
rm -rf "$XCFRAMEWORK"
mkdir -p "$VENDOR_DIR"
xcodebuild -create-xcframework \
    -library "$UNIVERSAL_DIR/libgit2.a" \
    -headers "$UNIVERSAL_DIR/include" \
    -output "$XCFRAMEWORK" > /dev/null

touch "$STAMP"
echo "==> Done: libgit2 $LIBGIT2_VERSION ($(lipo -archs "$UNIVERSAL_DIR/libgit2.a"))"
