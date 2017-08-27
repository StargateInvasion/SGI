shared float4x4	g_ViewProjection		: ViewProjection;

texture g_TextureDiffuse0 : Diffuse;
float colorMultiplier = 1.f;

void RenderSceneVS(
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

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = NULL;
		ZWriteEnable = false;
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		Texture[0] = <g_TextureDiffuse0>;
    }
}
