#include <metal_stdlib>
using namespace metal;

struct Vertex {
  float3 position;
  float4 color;
  float2 texcoord;
  float3 normal;
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
  float2 texcoord;
  float3 normal;
};

struct PerView {
  float4x4 viewMat;
  float4x4 projMat;
};

struct PerMaterial {
  float4 baseColorFactor;
};

struct PerDraw {
  float4x4 modelMat;
  float4x4 normalMat;
};

vertex VertexOut vertex_main(const device Vertex *vertices [[buffer(0)]],
                             const constant PerView *uniformsPerView
                             [[buffer(1)]],
                             const constant PerMaterial *uniformsPerMaterial
                             [[buffer(2)]],
                             const constant PerDraw *uniformsPerDraw
                             [[buffer(3)]],
                             uint vid [[vertex_id]]) {
  VertexOut vertexOut;
  vertexOut.position = uniformsPerView->projMat * uniformsPerView->viewMat *
                       uniformsPerDraw->modelMat *
                       float4(vertices[vid].position, 1);
  vertexOut.color = vertices[vid].color;
  vertexOut.texcoord = vertices[vid].texcoord;
  float3x3 normalMat33;
  normalMat33[0] = uniformsPerDraw->normalMat[0].xyz;
  normalMat33[1] = uniformsPerDraw->normalMat[1].xyz;
  normalMat33[2] = uniformsPerDraw->normalMat[2].xyz;
  vertexOut.normal = normalMat33 * vertices[vid].normal;
  return vertexOut;
}

fragment half4 fragment_main(VertexOut inVertex [[stage_in]],
                             texture2d<half> baseColorTexture [[texture(0)]],
                             sampler baseColorSampler [[sampler(0)]]) {
  // return half4(inVertex.color);
  // return half4(1, 1, 1, 1);

  // return half4(half3(inVertex.normal), 1);
  return half4(baseColorTexture.sample(baseColorSampler, inVertex.texcoord));
}
