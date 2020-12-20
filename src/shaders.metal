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
  float3 normal;
};

struct UniformBlock {
  float4x4 viewMat;
  float4x4 projMat;
};

struct PerDraw {
  float4x4 modelMat;
  float4x4 normalMat;
};

vertex VertexOut vertex_main(const device Vertex *vertices [[buffer(0)]],
                             const constant UniformBlock *uniforms
                             [[buffer(1)]],
                             const constant PerDraw* uniformsPerDraw [[buffer(2)]],
                             uint vid [[vertex_id]]) {
  VertexOut vertexOut;
  vertexOut.position =
      uniforms->projMat * uniforms->viewMat * uniformsPerDraw->modelMat * float4(vertices[vid].position, 1);
  vertexOut.color = vertices[vid].color;
  float3x3 normalMat33;
  normalMat33[0] = uniformsPerDraw->normalMat[0].xyz;
  normalMat33[1] = uniformsPerDraw->normalMat[1].xyz;
  normalMat33[2] = uniformsPerDraw->normalMat[2].xyz;
  vertexOut.normal = normalMat33 * vertices[vid].normal;
  return vertexOut;
}

fragment half4 fragment_main(VertexOut inVertex [[stage_in]]) {
  // return half4(inVertex.color);
  // return half4(1, 1, 1, 1);
  return half4(half3(inVertex.normal), 1);
}
