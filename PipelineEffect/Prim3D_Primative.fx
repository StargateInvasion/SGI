float4x4		g_WorldViewProjection	: WorldViewProjection;

texture			g_TextureDiffuse0		: Diffuse;


void
RenderSceneVS( 
	float3 iPosition		: POSITION, 
	float4 iColor0			: COLOR0,
	float2 iTexCoord0		: TEXCOORD0,
	out float4 oPosition	: POSITION,
    out float4 oColor0		: COLOR0,
    out float2 oTexCoord0	: TEXCOORD0 )
{
	oPosition = mul( float4( iPosition, 1 ), g_WorldViewProjection );
    oColor0	= iColor0;
    oTexCoord0 = iTexCoord0;
}



technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader		= compile vs_1_1 RenderSceneVS();
		PixelShader			= NULL;
		
		Texture[ 0 ]		= < g_TextureDiffuse0 >;
		
		AlphaBlendEnable	= true;
		SrcBlend			= one;
		DestBlend			= one;
		
		ZEnable				= false;
		ZWriteEnable		= false;			
    }
}
