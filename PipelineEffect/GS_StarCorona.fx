shared float4x4	g_ViewProjection	: ViewProjection;

texture			g_TextureDiffuse0	: Diffuse;
texture			g_TextureNoise3D;

float			g_Time;
float4			g_CoronaStartColor;
float4			g_CoronaEndColor;
float			g_CoronaStartColorDistance;
float			g_CoronaEndColorDistance;

float colorMultiplier = 1.f;

sampler TextureDiffuse0Sampler = 
sampler_state
{
    Texture		= < g_TextureDiffuse0 >;    
    MipFilter	= LINEAR;
    MinFilter	= LINEAR;
    MagFilter	= LINEAR;
};

sampler NoiseSampler 
= sampler_state 
{
    texture = < g_TextureNoise3D >;
    AddressU  = WRAP;        
    AddressV  = WRAP;
	AddressW  = WRAP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

void
RenderSceneVS_WithoutPixelShader( 
	float3 iPosition			: POSITION, 
	float4 iColor0				: COLOR0,
	float2 iTexCoord0			: TEXCOORD0,
	out float4 oPosition		: POSITION,
    out float4 oColor0			: COLOR0,
    out float2 oTexCoord0		: TEXCOORD0 )
{
	float dist = distance( iTexCoord0, float2(.5,.5) );

	float timeScale = 10.f;	
	float noiseScale = 1.f;
	
	float time = ( g_Time / timeScale );
	float3 index = float3( iTexCoord0.x, iTexCoord0.y, time ) * 2.f;
	
	float innerRingScalar = 2.5f;
	float noiseDist = ( dist + 1 / 5 ) * innerRingScalar;
	
	float4 colorByDistance = lerp( g_CoronaStartColor, g_CoronaEndColor, noiseDist );
	
	oColor0 = colorByDistance;	
   	oColor0.a = tex2D( TextureDiffuse0Sampler, iTexCoord0 ).a;   	

    oPosition = mul( float4( iPosition, 1 ), g_ViewProjection );
    oColor0	= iColor0;
    oColor0 *= colorMultiplier;
    oTexCoord0 = iTexCoord0; 
}

void
RenderSceneVS_WithPixelShader( 
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

float4
GetPixelColor( float4 iColor, float2 iTexCoord, float3 iViewNormal )
{
	float dist = min(.5,distance( iTexCoord, float2(.5,.5) ));//range 0 to .5
	float normalizedDist = dist * 2.f; //range 0 to 1
	normalizedDist = (normalizedDist - g_CoronaStartColorDistance) / (g_CoronaEndColorDistance - g_CoronaStartColorDistance);//range start to end

	float timeScale = 10.f;	
	float fractalScale = 4.f;
	
	float time = frac( g_Time / timeScale );
	float3 index = float3( iTexCoord.x, iTexCoord.y, time ) * fractalScale;
	
	float4 domainPhaseShift = tex3D( NoiseSampler, index ) * 2 - 1; //for range -1..1
		
	float variance = 2.f;
	float noiseDist = clamp( normalizedDist + domainPhaseShift.x / variance, 0, 1);
	
	float4 color = lerp( g_CoronaStartColor, g_CoronaEndColor, noiseDist );
	
   	color.a = tex2D( TextureDiffuse0Sampler, iTexCoord ).a;   	

    return color;
}

void
RenderScenePS_Color( 
	float4 iColor				: COLOR,
	float2 iTexCoord0			: TEXCOORD0,
	float3 iViewNormal			: TEXCOORD1,
	out float4 oColor0			: COLOR0 ) 
{ 
	oColor0 = GetPixelColor( iColor, iTexCoord0, iViewNormal );
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader			= compile vs_1_1 RenderSceneVS_WithoutPixelShader();
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
        VertexShader	= compile vs_1_1 RenderSceneVS_WithPixelShader();
        PixelShader		= compile ps_2_0 RenderScenePS_Color();
        
        ZWriteEnable			= FALSE;

		AlphaTestEnable			= FALSE;
		AlphaBlendEnable		= TRUE;
		SrcBlend				= SRCALPHA;
		DestBlend				= ONE;    
    }
}
