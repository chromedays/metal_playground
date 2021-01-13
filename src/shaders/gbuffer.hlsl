#include "common.hlsli"

VertexOut gbuffer_vert(VertexIn input) {
  VertexOut output;
  float4x4 mvp = mul(modelMat, mul(viewMat, projMat));
  
  output.position = mul(float4(input.position.xyz, 1), mvp);
  output.color = input.color;
  output.texcoord = input.texcoord;
  // float3x3 normalMat33 = (float3x3)normalMat;
  // output.normal = mul(input.normal, normalMat33);
  output.normal = input.normal;
  output.positionWorld = mul(float4(input.position.xyz, 1), modelMat);

  return output;
}

// GBuffer pixel data
// Texture 1: baseColor(rgb), metallic(a)
// Texture 2: normal(rgb), roughness(a)
// Texture 3: position(rgb), occlusion(a)
struct FragOut {
    float4 baseColorMetallic : SV_Target0;
    float4 normalRoughness : SV_Target1;
    float4 positionOcclusion : SV_Target2;
};

FragOut gbuffer_frag(VertexOut input) {
    FragOut output;
    output.baseColorMetallic = float4(input.color.rgb, 1);
    output.normalRoughness = float4(input.normal.xyz, 1);
    output.positionOcclusion = float4(input.positionWorld.xyz, 1);

    return output;
}