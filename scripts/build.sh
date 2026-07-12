#!/usr/bin/env bash
# Build OpenCASCADE (OCCT) as shared libraries on Linux.
#
# Usage: scripts/build.sh [Release|Debug|RelWithDebInfo]
#
# OCCT's CMake supports exactly these three configurations
# (CMAKE_CONFIGURATION_TYPES is forced to Release;Debug;RelWithDebInfo).
#
# Environment overrides:
#   OCCT_TAG      - OCCT git tag to build (default: V8_0_0_p1)
#   EIGEN_VERSION - Eigen version to fetch (default: 3.4.0)

set -euo pipefail

BUILD_TYPE="${1:-Release}"
case "$BUILD_TYPE" in
  Release|Debug|RelWithDebInfo) ;;
  *) echo "Unsupported build type '$BUILD_TYPE'. OCCT supports: Release, Debug, RelWithDebInfo" >&2; exit 1 ;;
esac

OCCT_TAG="${OCCT_TAG:-V8_0_0_p1}"
EIGEN_VERSION="${EIGEN_VERSION:-3.4.0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/_work"
SRC="$WORK/occt"
EIGEN_DIR="$WORK/eigen-$EIGEN_VERSION"
BUILD_DIR="$WORK/build-$BUILD_TYPE"
INSTALL_DIR="$WORK/install/occt-$BUILD_TYPE"
DIST_DIR="$WORK/dist"

mkdir -p "$WORK" "$DIST_DIR"

if [ ! -d "$SRC" ]; then
  git clone --depth 1 --branch "$OCCT_TAG" https://github.com/Open-Cascade-SAS/OCCT.git "$SRC"
  # Local fixes on top of the upstream tag (see patches/*.patch for rationale)
  for PATCH in "$ROOT"/patches/*.patch; do
    git -C "$SRC" apply --verbose "$PATCH"
  done
fi

# Eigen is header-only; OCCT only needs 3RDPARTY_EIGEN_INCLUDE_DIR to point at
# a directory containing the Eigen/ headers, so the unpacked source tree is enough.
if [ ! -d "$EIGEN_DIR" ]; then
  curl -fsSL "https://gitlab.com/libeigen/eigen/-/archive/$EIGEN_VERSION/eigen-$EIGEN_VERSION.tar.gz" | tar -xz -C "$WORK"
fi

# Modules:
#   FoundationClasses, ModelingData, ModelingAlgorithms - B-REP and geometry/mesh
#     data structures, queries and manipulation.
#   DataExchange - STEP, IGES, STL, OBJ, PLY, VRML readers/writers.
#   ApplicationFramework - OCAF/XCAF document layer required by the XDE
#     (TKXCAF/TKDE*) data-exchange toolkits.
#   Visualization - TKService/TKV3d are link-time dependencies of XCAF and the
#     mesh readers; built headless (no OpenGL/X11/FreeType, see USE_* below).
#   Draw - disabled (Tcl/Tk test harness, not needed).
#
# All USE_* third-party flags are OFF except USE_EIGEN.
#
# Release-only codegen tuning:
#   -march=x86-64-v2 - safe ISA baseline for distributed binaries (~2009+ CPUs).
#   -flto=auto       - parallelize the LTO link that BUILD_OPT_PROFILE=Production
#                      enables; GCC's bare -flto runs ltrans jobs serially under
#                      Ninja (no GNU make jobserver to detect).
OPT_FLAGS=""
if [ "$BUILD_TYPE" = "Release" ]; then
  OPT_FLAGS="-march=x86-64-v2 -flto=auto"
fi

cmake -S "$SRC" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_C_FLAGS="$OPT_FLAGS" \
  -DCMAKE_CXX_FLAGS="$OPT_FLAGS" \
  -DINSTALL_DIR="$INSTALL_DIR" \
  -DBUILD_LIBRARY_TYPE=Shared \
  -DBUILD_OPT_PROFILE=Production \
  -DBUILD_USE_PCH=ON \
  -DBUILD_MODULE_FoundationClasses=ON \
  -DBUILD_MODULE_ModelingData=ON \
  -DBUILD_MODULE_ModelingAlgorithms=ON \
  -DBUILD_MODULE_DataExchange=ON \
  -DBUILD_MODULE_ApplicationFramework=ON \
  -DBUILD_MODULE_Visualization=ON \
  -DBUILD_MODULE_Draw=OFF \
  -DBUILD_DOC_Overview=OFF \
  -DUSE_EIGEN=ON \
  -D3RDPARTY_EIGEN_INCLUDE_DIR="$EIGEN_DIR" \
  -DUSE_FREETYPE=OFF \
  -DUSE_TK=OFF \
  -DUSE_FREEIMAGE=OFF \
  -DUSE_FFMPEG=OFF \
  -DUSE_OPENVR=OFF \
  -DUSE_RAPIDJSON=OFF \
  -DUSE_DRACO=OFF \
  -DUSE_TBB=OFF \
  -DUSE_VTK=OFF \
  -DUSE_OPENGL=OFF \
  -DUSE_GLES2=OFF \
  -DUSE_XLIB=OFF \
  -DUSE_D3D=OFF

cmake --build "$BUILD_DIR"
cmake --build "$BUILD_DIR" --target install

ARCHIVE="$DIST_DIR/occt-$OCCT_TAG-linux-x64-$BUILD_TYPE.tar.gz"
tar -czf "$ARCHIVE" -C "$WORK/install" "occt-$BUILD_TYPE"
echo "Packaged: $ARCHIVE"
