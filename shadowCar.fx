#include "mta-helper.fx"

float4 shadowPosition = float4(-3000, -3000, 3000, 3000);
texture shadowMap;

sampler TexSampler = sampler_state
{
    Texture = (gTexture0);
};

sampler ShadowSampler = sampler_state
{
    Texture = (shadowMap);
    MinFilter = Linear;
    MagFilter = Linear;
};

struct VSInput
{
    float3 Position : POSITION;
    float4 Diffuse  : COLOR0;
    float3 Normal : NORMAL0;
    float2 TexCoord : TEXCOORD0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
    float3 WorldPos : TEXCOORD2;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;
    PS.Position = mul(float4(VS.Position, 1), gWorldViewProjection);
    float3 WorldNormal = MTACalcWorldNormal( VS.Normal );
    PS.Diffuse = MTACalcGTAVehicleDiffuse( WorldNormal, VS.Diffuse );
    PS.WorldPos = mul(float4(VS.Position.xyz,1), gWorld).xyz;
    PS.TexCoord = VS.TexCoord;

    return PS;
}

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float4 finalColor = tex2D(TexSampler, PS.TexCoord);
    finalColor = finalColor * PS.Diffuse;

    float attidute = (finalColor.r + finalColor.g + finalColor.b);

    if(PS.WorldPos.x >= shadowPosition.r && PS.WorldPos.y >= shadowPosition.g && PS.WorldPos.x <= shadowPosition.b && PS.WorldPos.y <= shadowPosition.a)
    {
        float2 uvPosition = float2((PS.WorldPos.x - shadowPosition.r) / (shadowPosition.b - shadowPosition.r), (PS.WorldPos.y - shadowPosition.g) / (shadowPosition.a - shadowPosition.g));
        float4 shadowColor = tex2D(ShadowSampler, uvPosition);
        finalColor.rgb *= shadowColor.rgb;
    }

    return finalColor;
}

technique complercated
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader  = compile ps_2_0 PixelShaderFunction();
    }
}