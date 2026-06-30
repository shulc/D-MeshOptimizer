cmake_minimum_required(VERSION 3.16)
project(d_meshoptimizer CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---- Vendored meshoptimizer (extern/meshoptimizer submodule) ----------------
# Disable shared-lib, demo, gltfpack, and install rules — we only want the
# static meshoptimizer target. MESHOPT_BUILD_SHARED_LIBS=OFF is the upstream
# default, but we set it explicitly so nothing can flip it.

set(MESHOPT_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(MESHOPT_BUILD_DEMO        OFF CACHE BOOL "" FORCE)
set(MESHOPT_BUILD_GLTFPACK    OFF CACHE BOOL "" FORCE)
set(MESHOPT_INSTALL           OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS         OFF CACHE BOOL "" FORCE)

add_subdirectory(extern/meshoptimizer EXCLUDE_FROM_ALL)

# meshoptimizer's own CMakeLists.txt exposes:
#   meshoptimizer — STATIC library target (when MESHOPT_BUILD_SHARED_LIBS=OFF)
#   include dir wired via target_include_directories INTERFACE
# Nothing else is needed from us — no shim, no csrc/.
