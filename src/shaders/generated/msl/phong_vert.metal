#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct type_ViewData
{
    float4x4 viewMat;
    float4x4 projMat;
};

struct type_DrawData
{
    float4x4 modelMat;
    float4x4 normalMat;
};

struct phong_vert_out
{
    float4 out_var_COLOR [[user(locn0)]];
    float2 out_var_TEXCOORD [[user(locn1)]];
    float3 out_var_NORMAL [[user(locn2)]];
    float4 gl_Position [[position]];
};

struct phong_vert_in
{
    float3 in_var_POSITION [[attribute(0)]];
    float4 in_var_COLOR [[attribute(1)]];
    float2 in_var_TEXCOORD [[attribute(2)]];
    float3 in_var_NORMAL [[attribute(3)]];
};

vertex phong_vert_out phong_vert(phong_vert_in in [[stage_in]], constant type_ViewData& ViewData [[buffer(0)]], constant type_DrawData& DrawData [[buffer(1)]])
{
    phong_vert_out out = {};
    out.gl_Position = ((ViewData.projMat * ViewData.viewMat) * DrawData.modelMat) * float4(in.in_var_POSITION, 1.0);
    out.out_var_COLOR = in.in_var_COLOR;
    out.out_var_TEXCOORD = in.in_var_TEXCOORD;
    out.out_var_NORMAL = float3x3(DrawData.modelMat[0].xyz, DrawData.modelMat[1].xyz, DrawData.modelMat[2].xyz) * in.in_var_NORMAL;
    return out;
}

