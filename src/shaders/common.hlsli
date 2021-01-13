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
