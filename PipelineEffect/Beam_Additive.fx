#define COLORPRESERVE
shared float4x4	g_ViewProjection : ViewProjection;

float4x4 g_TextureUVTransform;
texture g_TextureDiffuse0 : Diffuse;
float colorMultiplier = 1.f;

// removes any above 1 values to reduce white bloom
float3 preserveColor(float3 col)
{
	return 1.0 - (1.0 / (1 + pow(col, 2.2)));
}

void RenderSceneVS(
	float3 iPosition : POSITION, 
	float4 iColor0 : COLOR0,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oPosition : POSITION,
    out float4 oColor0 : COLOR0,
    out float2 oTexCoord0 : TEXCOORD0)
{
    oPosition = mul(float4(iPosition, 1), g_ViewProjection);
	#ifdef COLORPRESERVE
		oColor0	= float4(preserveColor(iColor0.rgb * colorMultiplier), iColor0.a);    
	#else
	    oColor0	= float4(iColor0.rgb * colorMultiplier, iColor0.a);   
	#endif
    oTexCoord0 = mul(float4(iTexCoord0, 0, 1), g_TextureUVTransform);
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader	= NULL;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;    
		Texture[0] = < g_TextureDiffuse0 >;
    }
}
