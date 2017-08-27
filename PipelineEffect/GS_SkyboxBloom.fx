shared float4x4	g_ViewProjection : ViewProjection;
float4x4 g_World;
float intensityThreshold = 1.f;
float colorMultiplier = 1.f;
texture	g_TextureDiffuse0 : Diffuse;

sampler TextureDiffuse0Sampler = 
sampler_state
{
    Texture		= < g_TextureDiffuse0 >;    
    MipFilter	= LINEAR;
    MinFilter	= LINEAR;
    MagFilter	= LINEAR;
};

void RenderSceneVS( 
	float3 iPosition : POSITION, 
	float3 iNormal : NORMAL,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oPosition : POSITION,
    out float4 oColor0 : COLOR0,
    out float2 oTexCoord0 : TEXCOORD0 )
{
	oPosition = mul(float4(iPosition, 1), g_World);
	oPosition = mul(oPosition, g_ViewProjection);
    oColor0 = float4(1, 1, 1, 1);
    oTexCoord0 = iTexCoord0;
}

void RenderScenePS( 
	float4 iColor : COLOR,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oColor0 : COLOR0 ) 
{ 
	oColor0 = tex2D(TextureDiffuse0Sampler, iTexCoord0);
	float intensity = dot(oColor0.rgb, float3(0.3, 0.59, 0.11));
	float p = smoothstep(intensityThreshold, 1.f, intensity);
	oColor0 = oColor0 * p * colorMultiplier;
}

technique RenderWithPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS();
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;      
    }
}

