#version 330

in vec4 POSITION;
in vec2 COLOR;
in vec3 TEXCOORD;
in vec4 NORMAL;
layout(location = 0) out vec4 out_var_SV_Target;

void main()
{
    out_var_SV_Target = vec4((TEXCOORD + vec3(1.0)) * 0.5, 1.0);
}

