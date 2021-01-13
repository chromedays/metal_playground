static float4 gl_Position;
static int gl_VertexIndex;
static float2 out_var_TEXCOORD;

struct SPIRV_Cross_Input
{
    uint gl_VertexIndex : SV_VertexID;
};

struct SPIRV_Cross_Output
{
    float2 out_var_TEXCOORD : TEXCOORD0;
    float4 gl_Position : SV_Position;
};

void vert_main()
{
    float2 _30 = float2(float((uint(gl_VertexIndex) << 1u) & 2u), float(uint(gl_VertexIndex) & 2u));
    gl_Position = float4((_30 * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
    out_var_TEXCOORD = _30;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    gl_VertexIndex = int(stage_input.gl_VertexIndex);
    vert_main();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.out_var_TEXCOORD = out_var_TEXCOORD;
    return stage_output;
}
