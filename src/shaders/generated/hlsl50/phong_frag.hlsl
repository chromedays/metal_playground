static float4 in_var_COLOR;
static float2 in_var_TEXCOORD0;
static float3 in_var_NORMAL;
static float4 in_var_TEXCOORD1;
static float4 out_var_SV_Target;

struct SPIRV_Cross_Input
{
    float4 in_var_COLOR : TEXCOORD0;
    float2 in_var_TEXCOORD0 : TEXCOORD1;
    float3 in_var_NORMAL : TEXCOORD2;
    float4 in_var_TEXCOORD1 : TEXCOORD3;
};

struct SPIRV_Cross_Output
{
    float4 out_var_SV_Target : SV_Target0;
};

void frag_main()
{
    out_var_SV_Target = float4((in_var_TEXCOORD1.xyz + 1.0f.xxx) * 0.5f, 1.0f);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_var_COLOR = stage_input.in_var_COLOR;
    in_var_TEXCOORD0 = stage_input.in_var_TEXCOORD0;
    in_var_NORMAL = stage_input.in_var_NORMAL;
    in_var_TEXCOORD1 = stage_input.in_var_TEXCOORD1;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.out_var_SV_Target = out_var_SV_Target;
    return stage_output;
}
