shared float4x4	g_ViewProjection : ViewProjection;

texture	g_TextureDiffuse0 : Diffuse;
texture g_TextureDiffuse1 : Diffuse;
float colorMultiplier = 1.f;

void RenderSceneFirstPassVS(
	float3 iPosition : POSITION, 
	float4 iColor0 : COLOR0,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oPosition : POSITION,
    out float4 oColor0 : COLOR0,
    out float2 oTexCoord0 : TEXCOORD0)
{
    oPosition = mul(float4(iPosition, 1), g_ViewProjection);
    oColor0	= float4(iColor0.rgb * colorMultiplier, iColor0.a);
    oTexCoord0 = iTexCoord0;
}

void RenderSceneSecondPassVS(
	float3 iPosition : POSITION, 
	float4 iColor0 : COLOR0,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oPosition : POSITION,
    out float4 oColor0 : COLOR0,
    out float2 oTexCoord0 : TEXCOORD0)
{
    oPosition = mul(float4(iPosition, 1), g_ViewProjection);
    float c = colorMultiplier;
    oColor0	= float4(c, c, c, iColor0[3]);
    oTexCoord0 = iTexCoord0;
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneFirstPassVS();
        PixelShader = NULL;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
		Texture[0] = <g_TextureDiffuse0>;
    }
    
	pass Pass1
    {   	        
        VertexShader = compile vs_1_1 RenderSceneSecondPassVS();
        PixelShader = NULL;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
		Texture[0] = <g_TextureDiffuse1>;
    }
}
