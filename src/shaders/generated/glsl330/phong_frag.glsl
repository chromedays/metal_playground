#version 330

layout(std140) uniform type_MaterialData
{
    vec4 baseColorFactor;
} MaterialData;

in vec4 in_var_COLOR;
in vec2 in_var_TEXCOORD;
in vec3 in_var_NORMAL;
layout(location = 0) out vec4 out_var_SV_Target;

void main()
{
    out_var_SV_Target = MaterialData.baseColorFactor * vec4(in_var_NORMAL, 1.0);
}

