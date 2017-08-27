float4x4		g_WorldViewProjection	: WorldViewProjection;

texture			g_TextureDiffuse0		: Diffuse;

sampler TextureDiffuse0Sampler = 
sampler_state
{
    Texture		= < g_TextureDiffuse0 >;    
    MipFilter	= LINEAR;
    MinFilter	= LINEAR;
    MagFilter	= LINEAR;
};

void
RenderSceneVS( 
	float3 iPosition			: POSITION, 
	float3 iNormal				: NORMAL,
	float2 iTexCoord0			: TEXCOORD0,
	out float4 oPosition		: POSITION,
	out float4 oColor0			: COLOR0,
	out float2 oTexCoord0		: TEXCOORD0 )
{
	oPosition = mul( float4( iPosition, 1.0f ), g_WorldViewProjection );
    oColor0	= float4( 1, 1, 1, 1 );
    oTexCoord0 = iTexCoord0; 
}

float4 GetPixelColor( float4 iColor, float2 iTexCoord )
{
	float4 diffuse = tex2D(TextureDiffuse0Sampler, iTexCoord);
	diffuse /= 5;
	return diffuse;
}

void
RenderScenePS_Color( 
	float4 iColor				: COLOR,
	float2 iTexCoord0			: TEXCOORD0,
	out float4 oColor0			: COLOR0 ) 
{ 
	oColor0 = GetPixelColor( iColor, iTexCoord0 );
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS_Color();
		ZEnable = true;
		ZWriteEnable = true;
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
    }
}
