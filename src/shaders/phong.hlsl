#pragma pack_matrix(row_major)

struct VertexIn {
  float3 position : POSITION;
  float4 color : COLOR;
  float2 texcoord : TEXCOORD;
  float3 normal : NORMAL;
};

struct VertexOut {
  float4 position : SV_POSITION;
  float4 color : COLOR;
  float2 texcoord : TEXCOORD0;
  float3 normal : NORMAL;

  float4 positionWorld : TEXCOORD1;
};

cbuffer ViewData : register(b0) {
  float4x4 viewMat;
  float4x4 projMat;
};

cbuffer MaterialData : register(b1) {
  float4 baseColorFactor;
};

cbuffer DrawData : register(b2) {
  float4x4 modelMat;
  float4x4 normalMat;
};

VertexOut phong_vert(VertexIn input) {
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

float4 phong_frag(VertexOut input) : SV_Target {
  return float4((input.normal.xyz + float3(1, 1, 1)) * 0.5, 1);
}