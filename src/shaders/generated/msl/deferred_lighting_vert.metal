#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct deferred_lighting_vert_out
{
    float2 out_var_TEXCOORD [[user(locn0)]];
    float4 gl_Position [[position]];
};

vertex deferred_lighting_vert_out deferred_lighting_vert(uint gl_VertexIndex [[vertex_id]])
{
    deferred_lighting_vert_out out = {};
    float2 _30 = float2(float((gl_VertexIndex << 1u) & 2u), float(gl_VertexIndex & 2u));
    out.gl_Position = float4((_30 * float2(2.0, -2.0)) + float2(-1.0, 1.0), 0.0, 1.0);
    out.out_var_TEXCOORD = _30;
    return out;
}

