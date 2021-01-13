#version 330

uniform sampler2D SPIRV_Cross_Combinedgbuffer1gbufferSampler;

in vec2 VertexOut0;
layout(location = 0) out vec4 out_var_SV_Target;

void main()
{
    out_var_SV_Target = texture(SPIRV_Cross_Combinedgbuffer1gbufferSampler, vec2(VertexOut0.x, 1.0 - VertexOut0.y));
}

