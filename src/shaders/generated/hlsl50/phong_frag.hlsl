cbuffer type_MaterialData : register(b1)
{
    float4 MaterialData_baseColorFactor : packoffset(c0);
};


static float4 in_var_COLOR;
static float2 in_var_TEXCOORD;
static float3 in_var_NORMAL;
static float4 out_var_SV_Target;

struct SPIRV_Cross_Input
{
    float4 in_var_COLOR : TEXCOORD0;
    float2 in_var_TEXCOORD : TEXCOORD1;
    float3 in_var_NORMAL : TEXCOORD2;
};

struct SPIRV_Cross_Output
{
    float4 out_var_SV_Target : SV_Target0;
};

void frag_main()
{
    out_var_SV_Target = MaterialData_baseColorFactor * float4(in_var_NORMAL, 1.0f);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_var_COLOR = stage_input.in_var_COLOR;
    in_var_TEXCOORD = stage_input.in_var_TEXCOORD;
    in_var_NORMAL = stage_input.in_var_NORMAL;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.out_var_SV_Target = out_var_SV_Target;
    return stage_output;
}
