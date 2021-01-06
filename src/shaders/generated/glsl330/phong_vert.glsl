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
out vec2 out_var_TEXCOORD;
out vec3 out_var_NORMAL;

void main()
{
    gl_Position = ((ViewData.projMat * ViewData.viewMat) * DrawData.modelMat) * vec4(in_var_POSITION, 1.0);
    out_var_COLOR = in_var_COLOR;
    out_var_TEXCOORD = in_var_TEXCOORD;
    out_var_NORMAL = mat3(DrawData.modelMat[0].xyz, DrawData.modelMat[1].xyz, DrawData.modelMat[2].xyz) * in_var_NORMAL;
}

