#version 330

in vec4 VertexOut0;
in vec2 VertexOut1;
in vec3 VertexOut2;
in vec4 VertexOut3;
layout(location = 0) out vec4 out_var_SV_Target0;
layout(location = 1) out vec4 out_var_SV_Target1;
layout(location = 2) out vec4 out_var_SV_Target2;

void main()
{
    out_var_SV_Target0 = vec4(VertexOut0.xyz, 1.0);
    out_var_SV_Target1 = vec4(VertexOut2, 1.0);
    out_var_SV_Target2 = vec4(VertexOut3.xyz, 1.0);
}

