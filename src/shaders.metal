#include <metal_stdlib>
using namespace metal;

struct Vertex
{
    float4 position [[position]];
    float4 color;
};

struct UniformBlock
{
    float4x4 mvp;
};

vertex Vertex vertex_main(const device Vertex* vertices [[buffer(0)]],
                          const constant UniformBlock* uniforms [[buffer(1)]],
                          uint vid [[vertex_id]]) {
    Vertex vertexOut;
    vertexOut.position = uniforms->mvp * vertices[vid].position;
    vertexOut.color = vertices[vid].color;
    return vertices[vid];
}

fragment half4 fragment_main(Vertex inVertex [[stage_in]]) {
    return half4(inVertex.color);
}
