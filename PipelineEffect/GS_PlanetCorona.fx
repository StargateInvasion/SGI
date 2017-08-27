shared float4x4	g_ViewProjection : ViewProjection;

float4x4	g_World						: World;
float4x4	g_WorldViewProjection		: WorldViewProjection;

float3		g_Light0_Position			: Position = float3( 0, 0, 0 );
texture		g_TextureDiffuse0			: Diffuse;
float3		g_PlanetPosition;

float colorMultiplier = 1.f;

sampler TextureDiffuse0Sampler = sampler_state
{
    Texture	= <g_TextureDiffuse0>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

void
RenderSceneVSSimple( 
	float3 iPosition			: POSITION, 
	float4 iColor0				: COLOR0,
	float2 iTexCoord0			: TEXCOORD0,
	out float4 oPosition		: POSITION,
    out float4 oColor0			: COLOR0,
    out float2 oTexCoord0		: TEXCOORD0 )
{
    oPosition = mul( float4( iPosition, 1 ), g_ViewProjection );
    oColor0	= iColor0;
    oTexCoord0 = iTexCoord0; 
}

struct VsOutput
{
	float4 Color: COLOR0;
	float4 Position: POSITION;
	float2 TexCoord0: TEXCOORD0;
	float3 Light: TEXCOORD1;
	float3 View: TEXCOORD2;
	float3 DirToPosition: TEXCOORD3;
};

VsOutput 
RenderSceneVS( float4 iColor0:COLOR0,float3 iPosition:POSITION, float3 iNormal:NORMAL, float2 iTexCoord:TEXCOORD0 )
{
	VsOutput o;  
	
	//Final Position
	o.Position = mul( float4( iPosition, 1.0f ), g_ViewProjection );
	
	//Texture Coordinates
    o.TexCoord0 = iTexCoord;     
 
    //Calculate Light
	o.Light = normalize( g_Light0_Position - iPosition );
	
	//Calculate ViewVector
	o.View = normalize( -iPosition );
	
	//Color
	o.Color = iColor0;

	//Direction to the Point
	o.DirToPosition = normalize( iPosition - float3( g_World._m30, g_World._m31, g_World._m32 ) );
	
    return o;
}

void 
RenderScenePS( VsOutput i, out float4 oColor0:COLOR0 ) 
{ 
	float3 light = normalize( i.Light );
	float3 view = normalize( i.View );
	float3 dirToPosition = normalize( i.DirToPosition );
	
	float dotLightView = 1.f - dot( light, view );
	float dotLightPosition = dot( light, dirToPosition );
		
	float4 diffuseSample = tex2D( TextureDiffuse0Sampler, i.TexCoord0 ); 
	
	oColor0 = diffuseSample * i.Color * saturate( dotLightPosition + dotLightView );
	oColor0 *= colorMultiplier;
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader			= compile vs_1_1 RenderSceneVSSimple();
        PixelShader				= NULL;

		ZWriteEnable			= FALSE;

		AlphaBlendEnable		= TRUE;
		SrcBlend				= SRCALPHA;
		DestBlend				= ONE;    

		Texture[ 0 ]			= < g_TextureDiffuse0 >;
    }
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS();
        
        ZWriteEnable			= FALSE;
        
        AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;    	
    }
}
