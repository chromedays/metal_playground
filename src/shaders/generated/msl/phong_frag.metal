#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct phong_frag_out
{
    float4 out_var_SV_Target [[color(0)]];
};

struct phong_frag_in
{
    float3 in_var_NORMAL [[user(locn2)]];
};

fragment phong_frag_out phong_frag(phong_frag_in in [[stage_in]])
{
    phong_frag_out out = {};
    out.out_var_SV_Target = float4((in.in_var_NORMAL + float3(1.0)) * 0.5, 1.0);
    return out;
}

