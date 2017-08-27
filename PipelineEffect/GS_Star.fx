float4x4		g_WorldViewProjection	: WorldViewProjection;

texture			g_TextureDiffuse0		: Diffuse;
texture			g_TextureNoise3D;

float			g_Time;

float postProcessColorMultiplier = 1.3f;

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
		
	float temperatureStart = 
		(0.3 * diffuse.r) + 
		(0.59 * diffuse.g) + 
		(0.14 * diffuse.b);

	float maxTime = 6.0f;
	float minTime = 5.9f;
	float timeScale = lerp( maxTime, minTime, temperatureStart );
	
	float time = g_Time;
	
	//keep time from getting too big
	if( time > maxTime )
	{
		time = time - maxTime;
	}
		
	float noiseTime = time / timeScale;
	float3 noiseIndex = float3(iTexCoord.x, iTexCoord.y, noiseTime);
	float domainPhaseShift = tex3D(NoiseSampler, noiseIndex);
	
	float2 shiftedCoord;
	shiftedCoord.x = iTexCoord.x + (cos(domainPhaseShift * 6.28) / 100.f);
	shiftedCoord.y = iTexCoord.y + (sin(domainPhaseShift * 6.28) / 100.f);
	diffuse = tex2D(TextureDiffuse0Sampler, shiftedCoord);
		
	return diffuse;
}

void
RenderScenePS_Color( 
	float4 iColor				: COLOR,
	float2 iTexCoord0			: TEXCOORD0,
	out float4 oColor0			: COLOR0 ) 
{ 
	oColor0 = GetPixelColor( iColor, iTexCoord0 );
	oColor0 *= postProcessColorMultiplier;
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = NULL;
		Texture[ 0 ] = < g_TextureDiffuse0 >;
		ZEnable = true;
		ZWriteEnable = true;
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
    }
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
