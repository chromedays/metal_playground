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
out vec4 POSITION;
out vec2 COLOR;
out vec3 TEXCOORD;
out vec4 NORMAL;

void main()
{
    vec4 _51 = vec4(in_var_POSITION, 1.0);
    gl_Position = ((ViewData.projMat * ViewData.viewMat) * DrawData.modelMat) * _51;
    POSITION = in_var_COLOR;
    COLOR = in_var_TEXCOORD;
    TEXCOORD = in_var_NORMAL;
    NORMAL = DrawData.modelMat * _51;
}

