Texture2D<float4> gbuffer1 : register(t0);
SamplerState gbufferSampler : register(s0);

static float2 in_var_TEXCOORD;
static float4 out_var_SV_Target;

struct SPIRV_Cross_Input
{
    float2 in_var_TEXCOORD : TEXCOORD0;
};

struct SPIRV_Cross_Output
{
    float4 out_var_SV_Target : SV_Target0;
};

void frag_main()
{
    out_var_SV_Target = float4((gbuffer1.Sample(gbufferSampler, float2(in_var_TEXCOORD.x, 1.0f - in_var_TEXCOORD.y)).xyz + 1.0f.xxx) * 0.5f, 1.0f);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_var_TEXCOORD = stage_input.in_var_TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.out_var_SV_Target = out_var_SV_Target;
    return stage_output;
}
