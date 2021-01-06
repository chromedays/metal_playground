#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct type_MaterialData
{
    float4 baseColorFactor;
};

struct phong_frag_out
{
    float4 out_var_SV_Target [[color(0)]];
};

struct phong_frag_in
{
    float3 in_var_NORMAL [[user(locn2)]];
};

fragment phong_frag_out phong_frag(phong_frag_in in [[stage_in]], constant type_MaterialData& MaterialData [[buffer(0)]])
{
    phong_frag_out out = {};
    out.out_var_SV_Target = MaterialData.baseColorFactor * float4(in.in_var_NORMAL, 1.0);
    return out;
}

