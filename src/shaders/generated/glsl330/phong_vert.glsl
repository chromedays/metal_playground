#version 330

layout(std140) uniform type_ViewData
{
    mat4 viewMat;
    mat4 projMat;
} ViewData;

layout(std140) uniform type_DrawData
{
    mat4 modelMat;
    mat4 normalMat;
} DrawData;

layout(location = 0) in vec3 in_var_POSITION;
layout(location = 1) in vec4 in_var_COLOR;
layout(location = 2) in vec2 in_var_TEXCOORD;
layout(location = 3) in vec3 in_var_NORMAL;
out vec4 out_var_COLOR;
out vec2 out_var_TEXCOORD0;
out vec3 out_var_NORMAL;
out vec4 out_var_TEXCOORD1;

void main()
{
    vec4 _51 = vec4(in_var_POSITION, 1.0);
    gl_Position = ((ViewData.projMat * ViewData.viewMat) * DrawData.modelMat) * _51;
    out_var_COLOR = in_var_COLOR;
    out_var_TEXCOORD0 = in_var_TEXCOORD;
    out_var_NORMAL = in_var_NORMAL;
    out_var_TEXCOORD1 = DrawData.modelMat * _51;
}

