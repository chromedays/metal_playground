#include "common.hlsli"

Texture2D gbuffer0 : register(t0);
Texture2D gbuffer1 : register(t0);
Texture2D gbuffer2 : register(t0);
SamplerState gbufferSampler : register(s0);

struct DeferredLightingVertexOut {
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD;
};

DeferredLightingVertexOut deferred_lighting_vert(uint id: SV_VERTEXID) {
	DeferredLightingVertexOut output;

	output.texcoord = float2((id << 1) & 2, id & 2);
	output.position = float4(output.texcoord * float2(2, -2) + float2(-1, 1), 0, 1);

    return output;
}

float4 deferred_lighting_frag(DeferredLightingVertexOut input) : SV_Target {
    return float4(gbuffer1.Sample(gbufferSampler, float2(input.texcoord.x, 1 - input.texcoord.y)));
}