#version 330

in vec4 in_var_COLOR;
in vec2 in_var_TEXCOORD0;
in vec3 in_var_NORMAL;
in vec4 in_var_TEXCOORD1;
layout(location = 0) out vec4 out_var_SV_Target;

void main()
{
    out_var_SV_Target = vec4((in_var_TEXCOORD1.xyz + vec3(1.0)) * 0.5, 1.0);
}

