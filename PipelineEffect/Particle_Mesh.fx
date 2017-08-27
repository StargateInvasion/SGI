float4x4 g_WorldViewProjection : WorldViewProjection;
texture g_TextureDiffuse0 : Diffuse;

float4 g_MeshColor;

void
RenderSceneVS( 
	float3 iPosition		: POSITION, 
	float2 iTexCoord0		: TEXCOORD0,
	out float4 oPosition	: POSITION,
    out float4 oColor0		: COLOR0,
    out float2 oTexCoord0	: TEXCOORD0 )
{
	oPosition = mul( float4( iPosition, 1 ), g_WorldViewProjection );
    oColor0 = g_MeshColor;
        
    oTexCoord0 = iTexCoord0; 
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader		= compile vs_1_1 RenderSceneVS();
		PixelShader			= NULL;
		
		AlphaTestEnable		= false;
		AlphaBlendEnable	= true;

		SrcBlend			= srcalpha;
		DestBlend			= invsrcalpha;
		
		ZEnable				= true;
  		ZWriteEnable		= false;
		
		Texture[ 0 ]		= < g_TextureDiffuse0 >;	
    }
}
