# Build OpenCASCADE (OCCT) as shared libraries (DLLs) on Windows with MSVC.
#
# Usage: scripts/build.ps1 -BuildType Release|Debug|RelWithDebInfo
#
# Must run inside an MSVC developer environment (vcvars / msvc-dev-cmd) so that
# cl.exe and ninja pick up the x64 toolchain.
#
# OCCT's CMake supports exactly these three configurations
# (CMAKE_CONFIGURATION_TYPES is forced to Release;Debug;RelWithDebInfo).
#
# Environment overrides:
#   OCCT_TAG      - OCCT git tag to build (default: V8_0_0_p1)
#   EIGEN_VERSION - Eigen version to fetch (default: 3.4.0)

param(
    [ValidateSet('Release', 'Debug', 'RelWithDebInfo')]
    [string]$BuildType = 'Release'
)

$ErrorActionPreference = 'Stop'

$OcctTag = if ($env:OCCT_TAG) { $env:OCCT_TAG } else { 'V8_0_0_p1' }
$EigenVersion = if ($env:EIGEN_VERSION) { $env:EIGEN_VERSION } else { '3.4.0' }

$Root = Split-Path -Parent $PSScriptRoot
$Work = Join-Path $Root '_work'
$Src = Join-Path $Work 'occt'
$EigenDir = Join-Path $Work "eigen-$EigenVersion"
$BuildDir = Join-Path $Work "build-$BuildType"
$InstallDir = Join-Path $Work "install/occt-$BuildType"
$DistDir = Join-Path $Work 'dist'

New-Item -ItemType Directory -Force -Path $Work, $DistDir | Out-Null

if (-not (Test-Path $Src)) {
    git clone --depth 1 --branch $OcctTag https://github.com/Open-Cascade-SAS/OCCT.git $Src
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
}

# Eigen is header-only; OCCT only needs 3RDPARTY_EIGEN_INCLUDE_DIR to point at
# a directory containing the Eigen/ headers, so the unpacked source tree is enough.
if (-not (Test-Path $EigenDir)) {
    $EigenArchive = Join-Path $Work "eigen-$EigenVersion.tar.gz"
    curl.exe -fsSL "https://gitlab.com/libeigen/eigen/-/archive/$EigenVersion/eigen-$EigenVersion.tar.gz" -o $EigenArchive
    if ($LASTEXITCODE -ne 0) { throw 'Eigen download failed' }
    tar -xzf $EigenArchive -C $Work
    if ($LASTEXITCODE -ne 0) { throw 'Eigen extraction failed' }
}

# Modules:
#   FoundationClasses, ModelingData, ModelingAlgorithms - B-REP and geometry/mesh
#     data structures, queries and manipulation.
#   DataExchange - STEP, IGES, STL, OBJ, PLY, VRML readers/writers.
#   ApplicationFramework - OCAF/XCAF document layer required by the XDE
#     (TKXCAF/TKDE*) data-exchange toolkits.
#   Visualization - TKService/TKV3d are link-time dependencies of XCAF and the
#     mesh readers; built headless (no OpenGL/D3D/FreeType, see USE_* below).
#   Draw - disabled (Tcl/Tk test harness, not needed).
#
# All USE_* third-party flags are OFF except USE_EIGEN.
cmake -S $Src -B $BuildDir -G Ninja `
    -DCMAKE_BUILD_TYPE="$BuildType" `
    -DINSTALL_DIR="$InstallDir" `
    -DBUILD_LIBRARY_TYPE=Shared `
    -DBUILD_MODULE_FoundationClasses=ON `
    -DBUILD_MODULE_ModelingData=ON `
    -DBUILD_MODULE_ModelingAlgorithms=ON `
    -DBUILD_MODULE_DataExchange=ON `
    -DBUILD_MODULE_ApplicationFramework=ON `
    -DBUILD_MODULE_Visualization=ON `
    -DBUILD_MODULE_Draw=OFF `
    -DBUILD_DOC_Overview=OFF `
    -DUSE_EIGEN=ON `
    -D3RDPARTY_EIGEN_INCLUDE_DIR="$EigenDir" `
    -DUSE_FREETYPE=OFF `
    -DUSE_TK=OFF `
    -DUSE_FREEIMAGE=OFF `
    -DUSE_FFMPEG=OFF `
    -DUSE_OPENVR=OFF `
    -DUSE_RAPIDJSON=OFF `
    -DUSE_DRACO=OFF `
    -DUSE_TBB=OFF `
    -DUSE_VTK=OFF `
    -DUSE_OPENGL=OFF `
    -DUSE_GLES2=OFF `
    -DUSE_XLIB=OFF `
    -DUSE_D3D=OFF
if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed' }

cmake --build $BuildDir
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }

cmake --build $BuildDir --target install
if ($LASTEXITCODE -ne 0) { throw 'Install failed' }

$Archive = Join-Path $DistDir "occt-$OcctTag-windows-x64-$BuildType.zip"
Compress-Archive -Path (Join-Path $Work "install/occt-$BuildType") -DestinationPath $Archive -Force
Write-Host "Packaged: $Archive"
