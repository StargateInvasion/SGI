float4x4		g_World					: World;
float4x4		g_View					: View;
float4x4		g_Projection			: Projection;

texture			g_TextureDiffuse0		: Diffuse;

float4			g_Light_Ambient			: Ambient;
bool			g_Light0_Enabled		: None			= true;
float3			g_Light0_ViewDirection	: Direction		= float3( 1, 0, 0 );
float4			g_Light0_Diffuse		: Diffuse		= float4( 1, 1, 1, 1 );

float4			g_MaterialAmbient		: Ambient;
float4			g_MaterialDiffuse		: Diffuse;



void
RenderSceneVS( 
	float4 iPosition		: POSITION, 
	float3 iNormal			: NORMAL,
	float2 iTexCoord0		: TEXCOORD0,
	out float4 oPosition	: POSITION, 
	out float4 oColor0		: COLOR0,
	out float2 oTexCoord0	: TEXCOORD0 )
{
    oPosition = mul( iPosition, mul( mul( g_World, g_View ), g_Projection ) );
    
	// NOTE: make full red to show this effect isn't normal ...
    oColor0.rgba = float4( 1, 0, 0, 1 );
    
    oTexCoord0 = iTexCoord0; 
}


technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader	= compile vs_1_1 RenderSceneVS();
		PixelShader		= NULL;
		
		Texture[ 0 ]	= NULL;
    }
}




