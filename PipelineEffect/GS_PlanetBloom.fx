float4x4 g_World : World;
float4x4 g_WorldViewProjection : WorldViewProjection;

texture	g_TextureDiffuse0 : Diffuse;
texture	g_TextureSelfIllumination;
float colorMultiplier = 1.f;

float3 g_Light0_Position: Position = float3( 0.f, 0.f, 0.f );

sampler TextureColorSampler = sampler_state{
    Texture = <g_TextureDiffuse0>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler TextureDataSampler = sampler_state{
    Texture = <g_TextureSelfIllumination>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

struct VsOutput
{
	float4 position	: POSITION;
	float2 texCoord : TEXCOORD0;
	float3 normal : TEXCOORD1;
	float3 lightDir : TEXCOORD2;
};

VsOutput RenderSceneVS( 
	float3 position : POSITION, 
	float3 normal : NORMAL,
	float3 tangent : TANGENT,
	float2 texCoord : TEXCOORD0 )
{
	VsOutput output;  
	output.position = mul(float4(position, 1.0f), g_WorldViewProjection);
    output.texCoord = texCoord; 
    output.normal = mul(normal, (float3x3)g_World);
    output.lightDir = normalize(g_Light0_Position - output.position);
    return output;
}

float4 RenderScenePS(VsOutput input) : COLOR0
{ 
	float4 lightSideSample = tex2D(TextureColorSampler, input.texCoord);
	float4 darkSideSample = tex2D(TextureDataSampler, input.texCoord);
	
	float dotLight = max(dot(input.lightDir, input.normal), 0.f);

	float4 finalColor = 0.f;	
	finalColor += lightSideSample * dotLight;
	finalColor += darkSideSample * (1.f - dotLight);
	
	return finalColor * darkSideSample.a * colorMultiplier;
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS();
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
}
