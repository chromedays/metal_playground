cbuffer type_ViewData : register(b0)
{
    row_major float4x4 ViewData_viewMat : packoffset(c0);
    row_major float4x4 ViewData_projMat : packoffset(c4);
};

cbuffer type_DrawData : register(b2)
{
    row_major float4x4 DrawData_modelMat : packoffset(c0);
    row_major float4x4 DrawData_normalMat : packoffset(c4);
};


static float4 gl_Position;
static float3 in_var_POSITION;
static float4 in_var_COLOR;
static float2 in_var_TEXCOORD;
static float3 in_var_NORMAL;
static float4 out_var_COLOR;
static float2 out_var_TEXCOORD0;
static float3 out_var_NORMAL;
static float4 out_var_TEXCOORD1;

struct SPIRV_Cross_Input
{
    float3 in_var_POSITION : TEXCOORD0;
    float4 in_var_COLOR : TEXCOORD1;
    float2 in_var_TEXCOORD : TEXCOORD2;
    float3 in_var_NORMAL : TEXCOORD3;
};

struct SPIRV_Cross_Output
{
    float4 out_var_COLOR : TEXCOORD0;
    float2 out_var_TEXCOORD0 : TEXCOORD1;
    float3 out_var_NORMAL : TEXCOORD2;
    float4 out_var_TEXCOORD1 : TEXCOORD3;
    float4 gl_Position : SV_Position;
};

void vert_main()
{
    float4 _51 = float4(in_var_POSITION, 1.0f);
    gl_Position = mul(_51, mul(DrawData_modelMat, mul(ViewData_viewMat, ViewData_projMat)));
    out_var_COLOR = in_var_COLOR;
    out_var_TEXCOORD0 = in_var_TEXCOORD;
    out_var_NORMAL = in_var_NORMAL;
    out_var_TEXCOORD1 = mul(_51, DrawData_modelMat);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_var_POSITION = stage_input.in_var_POSITION;
    in_var_COLOR = stage_input.in_var_COLOR;
    in_var_TEXCOORD = stage_input.in_var_TEXCOORD;
    in_var_NORMAL = stage_input.in_var_NORMAL;
    vert_main();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.out_var_COLOR = out_var_COLOR;
    stage_output.out_var_TEXCOORD0 = out_var_TEXCOORD0;
    stage_output.out_var_NORMAL = out_var_NORMAL;
    stage_output.out_var_TEXCOORD1 = out_var_TEXCOORD1;
    return stage_output;
}
