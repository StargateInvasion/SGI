shared float4x4	g_ViewProjection : ViewProjection;
float4x4 g_World;
float intensityThreshold = 2.0; // appears to compile out!?
const float colorMultiplier = 32.0; // appears to compile out!?
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
	out float3 oNormal	 : NORMAL,
    out float4 oColor0 : COLOR0,
    out float2 oTexCoord0 : TEXCOORD0 )
{
	oPosition = mul(float4(iPosition, 1), g_World);
	oPosition = mul(oPosition, g_ViewProjection);
	oNormal = iNormal;
    oColor0 = float4(1, 1, 1, 1);
    oTexCoord0 = iTexCoord0;
}

// removes any above 1 values to reduce white bloom
float3 preserveColor(float3 col)
{
	return 1.0 - (1.0 / (1 + pow(col, 2.2)));
}

float4 SRGBToLinear(float4 color)
{	
	#ifdef CHEAPLINEARCOLOR
		return float4(color.rgb * color.rgb, color.a);
	#else
		return float4(color.rgb * (color.rgb * (color.rgb * 0.305306011f + 0.682171111f) + 0.012522878f), color.a);
	#endif	
}

float4 LinearToSRGB(float4 color)
{
	float3 S1 = sqrt(color.rgb);
	#ifdef CHEAPLINEARCOLOR
		return float4(S1, color.a);
	#else		
		float3 S2 = sqrt(S1);
		float3 S3 = sqrt(S2);
		return float4(0.662002687 * S1 + 0.684122060 * S2 - 0.323583601 * S3 - 0.225411470 * color.rgb, color.a);
	#endif		
}

void RenderScenePS( 
	float3 iNormal : NORMAL,
	float4 iColor : COLOR,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oColor0 : COLOR0 ) 
{
	oColor0 = SRGBToLinear(tex2D(TextureDiffuse0Sampler, iTexCoord0));

	float intensity = dot(oColor0.rgb, float3(0.3, 0.59, 0.11));
//	float p = smoothstep(2.0, 1.f, intensity);
	oColor0 = oColor0 * 2.0;
	oColor0.rgb = preserveColor(oColor0.rgb);
}

technique RenderWithPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_3_0 RenderSceneVS();
        PixelShader = compile ps_3_0 RenderScenePS();
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;      
    }
}

