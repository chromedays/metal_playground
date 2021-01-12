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
layout(location = 2) in vec4 in_var_COLOR;
out vec4 out_var_COLOR;

void main()
{
    vec4 _51 = vec4(in_var_POSITION, 1.0);
    gl_Position = ((ViewData.projMat * ViewData.viewMat) * DrawData.modelMat) * _51;
    out_var_COLOR = in_var_COLOR;;
}

