/// D bindings for meshoptimizer v1.2 (https://github.com/zeux/meshoptimizer).
///
/// meshoptimizer.h declares its entire public API as `extern "C"`, so no C++
/// shim is needed — we bind directly. Only the core optimization and
/// simplification subset is exposed here; the full header is in
/// extern/meshoptimizer/src/meshoptimizer.h.
///
/// All size parameters map to D's `size_t` (= C `size_t`).  Unsigned-int
/// index buffers map to `uint`.  Use `.ptr` on D slices when passing to these
/// functions.
module meshoptimizer.c;

extern (C) @nogc nothrow:

// ---------------------------------------------------------------------------
// Vertex attribute stream (for multi-stream remap / generate calls)
// ---------------------------------------------------------------------------

/// Vertex attribute stream descriptor.
/// data   — pointer to the first element
/// size   — element size in bytes
/// stride — byte distance between successive elements (>= size)
struct meshopt_Stream
{
    const(void)* data;
    size_t       size;
    size_t       stride;
}

// ---------------------------------------------------------------------------
// Vertex remap / reindex
// ---------------------------------------------------------------------------

/// Generate a vertex remap table from a single vertex buffer + optional index
/// buffer.  Returns the number of unique vertices.
/// destination length = vertex_count; indices may be null (unindexed input).
size_t meshopt_generateVertexRemap(
    uint*        destination,
    const(uint)* indices,
    size_t       index_count,
    const(void)* vertices,
    size_t       vertex_count,
    size_t       vertex_size);

/// Multi-stream variant of meshopt_generateVertexRemap.
/// stream_count must be <= 16.
size_t meshopt_generateVertexRemapMulti(
    uint*                      destination,
    const(uint)*               indices,
    size_t                     index_count,
    size_t                     vertex_count,
    const(meshopt_Stream)*     streams,
    size_t                     stream_count);

/// Reorder the vertex buffer according to a remap table produced by
/// meshopt_generateVertexRemap*.
/// destination length = unique_vertex_count (returned by generate).
void meshopt_remapVertexBuffer(
    void*        destination,
    const(void)* vertices,
    size_t       vertex_count,
    size_t       vertex_size,
    const(uint)* remap);

/// Reorder the index buffer according to a remap table.
/// destination length = index_count; indices may be null (unindexed).
void meshopt_remapIndexBuffer(
    uint*        destination,
    const(uint)* indices,
    size_t       index_count,
    const(uint)* remap);

// ---------------------------------------------------------------------------
// Vertex cache optimizer
// ---------------------------------------------------------------------------

/// Reorder indices to reduce vertex shader invocations (Forsyth / Tipsy).
/// destination length = index_count.
void meshopt_optimizeVertexCache(
    uint*        destination,
    const(uint)* indices,
    size_t       index_count,
    size_t       vertex_count);

/// Strip-optimized variant: better for compression / strip length,
/// worse for GPU vertex cache ACMR.
void meshopt_optimizeVertexCacheStrip(
    uint*        destination,
    const(uint)* indices,
    size_t       index_count,
    size_t       vertex_count);

/// FIFO-cache variant (~3× faster, slightly worse quality).
/// cache_size should be < actual GPU cache size.
void meshopt_optimizeVertexCacheFifo(
    uint*        destination,
    const(uint)* indices,
    size_t       index_count,
    size_t       vertex_count,
    uint         cache_size);

// ---------------------------------------------------------------------------
// Overdraw optimizer
// ---------------------------------------------------------------------------

/// Reorder indices to reduce overdraw, accepting up to `threshold` factor
/// degradation of vertex cache efficiency (e.g. 1.05 = up to 5%).
/// indices must already be vertex-cache-optimized.
/// vertex_positions: float3 in first 12 bytes of each vertex.
void meshopt_optimizeOverdraw(
    uint*         destination,
    const(uint)*  indices,
    size_t        index_count,
    const(float)* vertex_positions,
    size_t        vertex_count,
    size_t        vertex_positions_stride,
    float         threshold);

// ---------------------------------------------------------------------------
// Vertex fetch optimizer
// ---------------------------------------------------------------------------

/// Reorder vertices + update indices to minimize GPU memory fetches.
/// Returns unique vertex count (== vertex_count unless some are unused).
/// destination length = vertex_count; indices is both input and output.
size_t meshopt_optimizeVertexFetch(
    void*        destination,
    uint*        indices,
    size_t       index_count,
    const(void)* vertices,
    size_t       vertex_count,
    size_t       vertex_size);

/// Remap-only variant; apply remap with meshopt_remapVertexBuffer/IndexBuffer.
/// destination length = vertex_count.
size_t meshopt_optimizeVertexFetchRemap(
    uint*        destination,
    const(uint)* indices,
    size_t       index_count,
    size_t       vertex_count);

// ---------------------------------------------------------------------------
// Simplification option flags (compose with |)
// ---------------------------------------------------------------------------

/// Do not move topological border vertices.
enum uint meshopt_SimplifyLockBorder     = 1 << 0;
/// Treat input as a sparse subset; error is relative to subset extents.
enum uint meshopt_SimplifySparse         = 1 << 1;
/// Treat error limit / result as absolute (not relative to mesh extents).
enum uint meshopt_SimplifyErrorAbsolute  = 1 << 2;
/// Remove disconnected components during simplification.
enum uint meshopt_SimplifyPrune         = 1 << 3;
/// Regularize triangle sizes / shapes.
enum uint meshopt_SimplifyRegularize    = 1 << 4;
/// Allow collapses across attribute seams (except protected vertices).
enum uint meshopt_SimplifyPermissive    = 1 << 5;
/// Lighter regularization (less quality cost).
enum uint meshopt_SimplifyRegularizeLight = 1 << 6;

// ---------------------------------------------------------------------------
// Simplification vertex lock flags
// ---------------------------------------------------------------------------

/// Pin vertex in place — never collapse it.
enum ubyte meshopt_SimplifyVertex_Lock    = 1 << 0;
/// Protect seam at vertex (use with meshopt_SimplifyPermissive).
enum ubyte meshopt_SimplifyVertex_Protect = 1 << 1;
/// Increase collapse priority for this vertex.
enum ubyte meshopt_SimplifyVertex_Priority = 1 << 2;

// ---------------------------------------------------------------------------
// Mesh simplifier (quality — topology-preserving)
// ---------------------------------------------------------------------------

/// Reduce index count, preserving visual quality.
/// destination must hold index_count elements (worst case = no reduction).
/// vertex_positions: float3 in first 12 bytes of each vertex.
/// target_error: relative to mesh extents, e.g. 0.01 = 1% deformation.
/// options: bitmask of meshopt_SimplifyX; 0 is safe.
/// result_error: filled with achieved error; may be null.
/// Returns resulting index count.
size_t meshopt_simplify(
    uint*         destination,
    const(uint)*  indices,
    size_t        index_count,
    const(float)* vertex_positions,
    size_t        vertex_count,
    size_t        vertex_positions_stride,
    size_t        target_index_count,
    float         target_error,
    uint          options,
    float*        result_error);

/// Attribute-aware simplifier — incorporates attribute values into the error
/// metric.  attribute_count must be <= 32.  vertex_lock may be null.
size_t meshopt_simplifyWithAttributes(
    uint*          destination,
    const(uint)*   indices,
    size_t         index_count,
    const(float)*  vertex_positions,
    size_t         vertex_count,
    size_t         vertex_positions_stride,
    const(float)*  vertex_attributes,
    size_t         vertex_attributes_stride,
    const(float)*  attribute_weights,
    size_t         attribute_count,
    const(ubyte)*  vertex_lock,
    size_t         target_index_count,
    float          target_error,
    uint           options,
    float*         result_error);

// ---------------------------------------------------------------------------
// Mesh simplifier (sloppy — ignores topology)
// ---------------------------------------------------------------------------

/// Fast but topology-ignoring simplification.
/// vertex_lock may be null.  target_error in [0..1].
size_t meshopt_simplifySloppy(
    uint*         destination,
    const(uint)*  indices,
    size_t        index_count,
    const(float)* vertex_positions,
    size_t        vertex_count,
    size_t        vertex_positions_stride,
    const(ubyte)* vertex_lock,
    size_t        target_index_count,
    float         target_error,
    float*        result_error);

// ---------------------------------------------------------------------------
// Simplification scale helper
// ---------------------------------------------------------------------------

/// Returns the scaling factor that converts between absolute and relative
/// error for meshopt_simplify.
/// Absolute → divide by scale before passing as target_error.
/// Relative result_error → multiply by scale to get absolute error.
float meshopt_simplifyScale(
    const(float)* vertex_positions,
    size_t        vertex_count,
    size_t        vertex_positions_stride);

// ---------------------------------------------------------------------------
// Statistics structs (useful for tuning / assertions)
// ---------------------------------------------------------------------------

struct meshopt_VertexCacheStatistics
{
    uint  vertices_transformed;
    uint  warps_executed;
    float acmr; /// transformed vertices / triangle count
    float atvr; /// transformed vertices / vertex count
}

struct meshopt_VertexFetchStatistics
{
    uint  bytes_fetched;
    float overfetch; /// fetched bytes / vertex buffer size
}

struct meshopt_OverdrawStatistics
{
    uint  pixels_covered;
    uint  pixels_shaded;
    float overdraw; /// shaded / covered; best = 1.0
}

/// Vertex cache analysis (FIFO model).
meshopt_VertexCacheStatistics meshopt_analyzeVertexCache(
    const(uint)* indices,
    size_t       index_count,
    size_t       vertex_count,
    uint         cache_size,
    uint         warp_size,
    uint         primgroup_size);

/// Vertex fetch analysis (direct-mapped model).
meshopt_VertexFetchStatistics meshopt_analyzeVertexFetch(
    const(uint)* indices,
    size_t       index_count,
    size_t       vertex_count,
    size_t       vertex_size);

/// Overdraw analysis (software rasterizer).
/// vertex_positions: float3 in first 12 bytes of each vertex.
meshopt_OverdrawStatistics meshopt_analyzeOverdraw(
    const(uint)*  indices,
    size_t        index_count,
    const(float)* vertex_positions,
    size_t        vertex_count,
    size_t        vertex_positions_stride);
