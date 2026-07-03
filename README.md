# libocct-build

Build scripts and CI pipeline that compile [OpenCASCADE Technology (OCCT)](https://github.com/Open-Cascade-SAS/OCCT)
as **shared libraries** for **Linux (x64)** and **Windows (x64, MSVC)** and publish
the binaries as GitHub Release assets.

## What is built

- OCCT tag: `V8_0_0_p1` (pinned in `scripts/build.*` and `.github/workflows/build.yml` via `OCCT_TAG`)
- Library type: `Shared`
- Configurations: `Release`, `Debug`, `RelWithDebInfo` — all build types OCCT's CMake
  supports (it forces `CMAKE_CONFIGURATION_TYPES` to exactly these three; `MinSizeRel`
  is not supported upstream)

### Modules

| Module | State | Why |
|---|---|---|
| FoundationClasses | ON | Core kernel, math |
| ModelingData | ON | B-REP and geometry data structures, queries |
| ModelingAlgorithms | ON | B-REP manipulation, booleans, meshing (BRepMesh) |
| DataExchange | ON | STEP, IGES, STL, OBJ, PLY, VRML readers/writers |
| ApplicationFramework | ON | OCAF/XCAF document layer required by the XDE data-exchange toolkits |
| Visualization | ON (headless) | `TKService`/`TKV3d` are link-time dependencies of XCAF and the mesh readers; built without OpenGL/X11/FreeType |
| Draw | OFF | Tcl/Tk test harness, not needed |

### Third-party options

Every `USE_*` flag is **OFF** except `USE_EIGEN=ON` (Eigen 3.4.0 headers are
downloaded automatically during the build). Consequences worth knowing:

- No Tcl/Tk, FreeType, FreeImage, FFmpeg, VTK, TBB, OpenVR dependencies —
  the resulting libraries only depend on system runtime libraries.
- glTF **reading** is unavailable (requires `USE_RAPIDJSON`); glTF writing and
  Draco-compressed glTF are likewise off. STEP, IGES, STL, OBJ, PLY, VRML work.
- No rendering: OpenGL/GLES/D3D/X11 are disabled. Visualization toolkits are
  built only to satisfy link dependencies (structures, selection, presentation
  data), not to open windows or render.

## Local build

Linux:

```sh
./scripts/build.sh Release        # or Debug / RelWithDebInfo
```

Windows (from an *x64 Native Tools* developer prompt, requires Ninja):

```powershell
.\scripts\build.ps1 -BuildType Release
```

The script clones OCCT, downloads Eigen, configures, builds, installs into
`_work/install/occt-<BuildType>/` and packages an archive into `_work/dist/`.

## CI

`.github/workflows/build.yml` runs a 2 (OS) x 3 (build type) matrix on every push
to `main` (and on manual dispatch), uploads each build as a workflow artifact, and
then creates/updates the `occt-V8_0_0_p1` GitHub Release with all six archives.

## Upgrading OCCT

Change `OCCT_TAG` in `.github/workflows/build.yml` (and the default in
`scripts/build.sh` / `scripts/build.ps1`), push to `main`, and a new release
`occt-<tag>` is produced.
