#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct gbuffer_frag_out
{
    float4 out_var_SV_Target0 [[color(0)]];
    float4 out_var_SV_Target1 [[color(1)]];
    float4 out_var_SV_Target2 [[color(2)]];
};

struct gbuffer_frag_in
{
    float4 in_var_COLOR [[user(locn0)]];
    float3 in_var_NORMAL [[user(locn2)]];
    float4 in_var_TEXCOORD1 [[user(locn3)]];
};

fragment gbuffer_frag_out gbuffer_frag(gbuffer_frag_in in [[stage_in]])
{
    gbuffer_frag_out out = {};
    out.out_var_SV_Target0 = float4(in.in_var_COLOR.xyz, 1.0);
    out.out_var_SV_Target1 = float4(in.in_var_NORMAL, 1.0);
    out.out_var_SV_Target2 = float4(in.in_var_TEXCOORD1.xyz, 1.0);
    return out;
}

