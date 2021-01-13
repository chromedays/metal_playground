#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct deferred_lighting_frag_out
{
    float4 out_var_SV_Target [[color(0)]];
};

struct deferred_lighting_frag_in
{
    float2 in_var_TEXCOORD [[user(locn0)]];
};

fragment deferred_lighting_frag_out deferred_lighting_frag(deferred_lighting_frag_in in [[stage_in]], texture2d<float> gbuffer1 [[texture(0)]], sampler gbufferSampler [[sampler(0)]])
{
    deferred_lighting_frag_out out = {};
    out.out_var_SV_Target = gbuffer1.sample(gbufferSampler, float2(in.in_var_TEXCOORD.x, 1.0 - in.in_var_TEXCOORD.y));
    return out;
}

