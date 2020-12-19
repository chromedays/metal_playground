#include <metal_stdlib>
using namespace metal;

struct Vertex {
  float4 position [[position]];
  float4 color;
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
  float pointSize [[point_size]];
};

struct UniformBlock {
  float4x4 modelMat;
  float4x4 projMat;
};

vertex VertexOut vertex_main(const device Vertex *vertices [[buffer(0)]],
                             const constant UniformBlock *uniforms
                             [[buffer(1)]],
                             uint vid [[vertex_id]]) {
  VertexOut vertexOut;
  vertexOut.position =
      uniforms->projMat * uniforms->modelMat * vertices[vid].position;
  vertexOut.color = vertices[vid].color;
  vertexOut.pointSize = 10;
  return vertexOut;
}

fragment half4 fragment_main(VertexOut inVertex [[stage_in]]) {
  return half4(inVertex.color);
}
