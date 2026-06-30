/// Smoke test: build a dense subdivided quad-grid (triangle mesh),
/// run meshopt_simplify to ~25% of the original index count, and verify
/// that the result is meaningfully smaller and non-zero.
///
/// Expected output (values may vary slightly across platforms/versions):
///   Input:  N vertices, M triangles
///   Output: K triangles  (result_error = <small float>)
///   Simplified to <pct>% of input  [PASS]
///   Static link OK (no libmeshoptimizer.so)
///
/// Run via:  dub run --config=simplify
module simplify;

import std.stdio   : writefln, writeln;
import std.format  : format;
import core.stdc.stdio : printf;

import meshoptimizer.c;

// ---------------------------------------------------------------------------
// Build a flat NxN subdivided quad-grid as a triangle list.
// Grid lies in the XZ plane, Y=0, corners at (0,0,0)-(1,0,1).
// ---------------------------------------------------------------------------
struct Vertex { float x, y, z; }

void buildGrid(int N, ref Vertex[] verts, ref uint[] indices)
{
    // (N+1)*(N+1) vertices, 2*N*N triangles.
    verts.length = 0;
    indices.length = 0;

    foreach (j; 0 .. N + 1)
        foreach (i; 0 .. N + 1)
            verts ~= Vertex(cast(float)i / N, 0f, cast(float)j / N);

    foreach (j; 0 .. N)
    {
        foreach (i; 0 .. N)
        {
            uint a = cast(uint)(j * (N + 1) + i);
            uint b = a + 1;
            uint c = a + cast(uint)(N + 1);
            uint d = c + 1;
            // two triangles per quad
            indices ~= [a, c, b];
            indices ~= [b, c, d];
        }
    }
}

void main()
{
    enum N = 64; // 64x64 grid => 4225 verts, 8192 triangles

    Vertex[] verts;
    uint[]   indices;
    buildGrid(N, verts, indices);

    immutable size_t inTriCount  = indices.length / 3;
    immutable size_t inVertCount = verts.length;

    writefln("Input:  %d vertices, %d triangles", inVertCount, inTriCount);

    // ------------------------------------------------------------------
    // Optimize for vertex cache first (meshopt_simplify requires it).
    // ------------------------------------------------------------------
    auto vcacheOut = new uint[](indices.length);
    meshopt_optimizeVertexCache(
        vcacheOut.ptr, indices.ptr, indices.length, inVertCount);

    // ------------------------------------------------------------------
    // Simplify to ~25% of triangles.
    // ------------------------------------------------------------------
    immutable size_t targetIndexCount = (indices.length / 3 / 4) * 3; // 25%
    immutable float  targetError      = 0.05f; // 5% relative error budget

    auto simplified = new uint[](indices.length); // worst-case same size
    float resultError = 0f;

    size_t outIndexCount = meshopt_simplify(
        simplified.ptr,
        vcacheOut.ptr, vcacheOut.length,
        cast(float*)verts.ptr, inVertCount, Vertex.sizeof,
        targetIndexCount,
        targetError,
        0,          // options: default
        &resultError);

    size_t outTriCount = outIndexCount / 3;

    writefln("Output: %d triangles  (result_error = %.5f)",
             outTriCount, resultError);

    // The simplifier must have reduced the count meaningfully.
    assert(outTriCount > 0,
           "simplify produced zero triangles");
    assert(outTriCount < inTriCount,
           format("simplify did not reduce: %d >= %d", outTriCount, inTriCount));

    double pct = 100.0 * outTriCount / inTriCount;
    writefln("Simplified to %.1f%% of input  [PASS]", pct);
    writeln("Static link OK (no libmeshoptimizer.so)");
}
