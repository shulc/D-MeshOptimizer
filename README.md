# D-MeshOptimizer

D bindings for **[meshoptimizer](https://github.com/zeux/meshoptimizer)** v1.2 — a mesh optimization library by Arseny Kapoulkine that improves GPU rendering efficiency via vertex cache, overdraw, vertex fetch, and simplification passes.

No C++ shim is needed: meshoptimizer's header (`src/meshoptimizer.h`) declares the entire public API as `extern "C"`, so `source/meshoptimizer/c.d` binds it directly.

## Layout

```
source/meshoptimizer/c.d    — D extern(C) bindings, core optimization + simplify subset
CMakeLists.txt              — builds libmeshoptimizer.a via add_subdirectory
extern/meshoptimizer        — git submodule, pinned to v1.2
examples/simplify.d         — smoke test: subdivided grid → meshopt_simplify → ldd proof
dub.json                    — name "d-meshoptimizer", library + simplify configurations
```

## First build

```sh
git submodule update --init --recursive
dub build
```

The `preBuildCommands-posix` hook in `dub.json` runs CMake to build
`libmeshoptimizer.a` in `build/extern/meshoptimizer/` before dub compiles
the D side.  A plain `dub build` is enough.

## Smoke test

```sh
dub run --config=simplify
```

Expected output (values may vary slightly across platforms):

```
Input:  4225 vertices, 8192 triangles
Output: <K> triangles  (result_error = <small float>)
Simplified to <pct>% of input  [PASS]
Static link OK (no libmeshoptimizer.so)
```

Then verify static linking:

```sh
ldd simplify | grep meshoptimizer   # should print nothing
```

## Consuming from another dub project

```json
"dependencies": {
    "d-meshoptimizer": { "path": "../D-MeshOptimizer" }
}
```

```d
import meshoptimizer.c;

// 1. Generate remap and reindex
auto remap = new uint[](vertexCount);
size_t uniqueVerts = meshopt_generateVertexRemap(
    remap.ptr, indices.ptr, indices.length,
    verts.ptr, verts.length, Vertex.sizeof);

auto newVerts   = new Vertex[](uniqueVerts);
auto newIndices = new uint[](indices.length);
meshopt_remapVertexBuffer(newVerts.ptr, verts.ptr, verts.length, Vertex.sizeof, remap.ptr);
meshopt_remapIndexBuffer(newIndices.ptr, indices.ptr, indices.length, remap.ptr);

// 2. Optimize for GPU
auto vcOpt = new uint[](newIndices.length);
meshopt_optimizeVertexCache(vcOpt.ptr, newIndices.ptr, newIndices.length, uniqueVerts);
meshopt_optimizeOverdraw(vcOpt.ptr, vcOpt.ptr, vcOpt.length,
                         cast(float*)newVerts.ptr, uniqueVerts, Vertex.sizeof, 1.05f);
meshopt_optimizeVertexFetch(newVerts.ptr, vcOpt.ptr, vcOpt.length,
                            newVerts.ptr, uniqueVerts, Vertex.sizeof);

// 3. Simplify (optional)
auto simplified = new uint[](vcOpt.length);
float err;
size_t outCount = meshopt_simplify(
    simplified.ptr, vcOpt.ptr, vcOpt.length,
    cast(float*)newVerts.ptr, uniqueVerts, Vertex.sizeof,
    vcOpt.length / 4,  // target 25%
    0.05f, 0, &err);
```

## Bound subset

`source/meshoptimizer/c.d` covers:

| Group | Functions |
|---|---|
| Remap / reindex | `meshopt_generateVertexRemap`, `meshopt_generateVertexRemapMulti`, `meshopt_remapVertexBuffer`, `meshopt_remapIndexBuffer` |
| Vertex cache | `meshopt_optimizeVertexCache`, `meshopt_optimizeVertexCacheStrip`, `meshopt_optimizeVertexCacheFifo` |
| Overdraw | `meshopt_optimizeOverdraw` |
| Vertex fetch | `meshopt_optimizeVertexFetch`, `meshopt_optimizeVertexFetchRemap` |
| Simplify | `meshopt_simplify`, `meshopt_simplifyWithAttributes`, `meshopt_simplifySloppy`, `meshopt_simplifyScale` |
| Analysis | `meshopt_analyzeVertexCache`, `meshopt_analyzeVertexFetch`, `meshopt_analyzeOverdraw` |
| Structs | `meshopt_Stream`, `meshopt_VertexCacheStatistics`, `meshopt_VertexFetchStatistics`, `meshopt_OverdrawStatistics` |
| Option flags | `meshopt_SimplifyLockBorder`, `meshopt_SimplifySparse`, `meshopt_SimplifyErrorAbsolute`, `meshopt_SimplifyPrune`, `meshopt_SimplifyRegularize`, `meshopt_SimplifyPermissive`, `meshopt_SimplifyRegularizeLight` |
| Vertex lock | `meshopt_SimplifyVertex_Lock`, `meshopt_SimplifyVertex_Protect`, `meshopt_SimplifyVertex_Priority` |

Encoder/decoder, meshlet, stripifier, and experimental APIs are in the upstream header but not yet bound here — they can be added to `c.d` following the same `extern (C) @nogc nothrow` pattern.

## License

MIT — see `LICENSE`.  meshoptimizer upstream is also MIT (© Arseny Kapoulkine).
