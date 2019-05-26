#define COLORPRESERVE
shared float4x4	g_ViewProjection : ViewProjection;

float4x4 g_TextureUVTransform;
texture g_TextureDiffuse0 : Diffuse;
float colorMultiplier = 1.f;

/*
// WARNING looks like this function is somehow compiled out on certain cards... Might not have been legit on vs_1_1 - and some cards just REALLY follow the ancient rules...?
// removes any above 1 values to reduce white bloom
float3 preserveColor(float3 col)
{
	return (1.0 - (1.0 / (1 + col * (col * (col * 0.305306011f + 0.682171111f) + 0.012522878f))));
}
*/

void RenderSceneVS(
	float3 iPosition : POSITION, 
	float4 iColor0 : COLOR0,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oPosition : POSITION,
    out float4 oColor0 : COLOR0,
    out float2 oTexCoord0 : TEXCOORD0)
{
    oPosition = mul(float4(iPosition, 1), g_ViewProjection);
	oColor0.rgb = iColor0.rgb * colorMultiplier;
	oColor0	= float4((1.0 - (1.0 / (1.0 + oColor0.rgb * (oColor0.rgb * (oColor0.rgb * 0.305306011f + 0.682171111f) + 0.012522878f)))), iColor0.a);    
    oTexCoord0 = mul(float4(iTexCoord0, 0, 1), g_TextureUVTransform);
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = NULL;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		Texture[0] = < g_TextureDiffuse0 >;
    }
}
