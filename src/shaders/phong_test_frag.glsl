#version 330

in vec4 out_var_COLOR;
in vec2 out_var_TEXCOORD0;
in vec3 out_var_NORMAL;
in vec4 out_var_TEXCOORD1;
layout(location = 0) out vec4 out_var_SV_Target;

void main()
{
    out_var_SV_Target = vec4(out_var_NORMAL, 1.0);
}

