float4x4 g_WorldViewProjection : WorldViewProjection;

texture	g_TextureDiffuse0 : Diffuse;

float2 g_DiffuseTextureSize;
float2 g_DebugTextureSize;

sampler TextureColorSampler = sampler_state{
    Texture = <g_TextureDiffuse0>;
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

struct VsOutput
{
	float4 Position	: POSITION;
	float2 TexCoord : TEXCOORD0;
};

VsOutput RenderSceneVS( 
	float3 position : POSITION, 
	float3 normal : NORMAL,
	float3 tangent : TANGENT,
	float2 texCoord : TEXCOORD0)
{
	VsOutput output;
	
	output.Position = mul(float4(position, 1.0f), g_WorldViewProjection);
	output.TexCoord = float2(texCoord.x * g_DiffuseTextureSize.x / g_DebugTextureSize.x,
		texCoord.y * g_DiffuseTextureSize.y / g_DebugTextureSize.y);
    
    return output;
}

float4 GetFinalPixelColor(float2 texCoord)
{
	return tex2D(TextureColorSampler, texCoord);
}

float4 RenderScenePS(VsOutput input) : COLOR0
{ 
	return GetFinalPixelColor(input.TexCoord);
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_3_0 RenderSceneVS();
        PixelShader = compile ps_3_0 RenderScenePS();
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
}
