#version 330

in vec4 VertexOut0;
in vec2 VertexOut1;
in vec3 VertexOut2;
in vec4 VertexOut3;
layout(location = 0) out vec4 out_var_SV_Target;

void main()
{
    out_var_SV_Target = vec4((VertexOut2 + vec3(1.0)) * 0.5, 1.0);
}

