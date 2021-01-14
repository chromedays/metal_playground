static float4 in_var_COLOR;
static float2 in_var_TEXCOORD0;
static float3 in_var_NORMAL;
static float4 in_var_TEXCOORD1;
static float4 out_var_SV_Target0;
static float4 out_var_SV_Target1;
static float4 out_var_SV_Target2;

struct SPIRV_Cross_Input
{
    float4 in_var_COLOR : TEXCOORD0;
    float2 in_var_TEXCOORD0 : TEXCOORD1;
    float3 in_var_NORMAL : TEXCOORD2;
    float4 in_var_TEXCOORD1 : TEXCOORD3;
};

struct SPIRV_Cross_Output
{
    float4 out_var_SV_Target0 : SV_Target0;
    float4 out_var_SV_Target1 : SV_Target1;
    float4 out_var_SV_Target2 : SV_Target2;
};

void frag_main()
{
    out_var_SV_Target0 = float4(in_var_COLOR.xyz, 1.0f);
    out_var_SV_Target1 = float4(in_var_NORMAL, 1.0f);
    out_var_SV_Target2 = float4(in_var_TEXCOORD1.xyz, 1.0f);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_var_COLOR = stage_input.in_var_COLOR;
    in_var_TEXCOORD0 = stage_input.in_var_TEXCOORD0;
    in_var_NORMAL = stage_input.in_var_NORMAL;
    in_var_TEXCOORD1 = stage_input.in_var_TEXCOORD1;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.out_var_SV_Target0 = out_var_SV_Target0;
    stage_output.out_var_SV_Target1 = out_var_SV_Target1;
    stage_output.out_var_SV_Target2 = out_var_SV_Target2;
    return stage_output;
}