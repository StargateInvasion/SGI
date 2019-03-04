shared float4x4	g_ViewProjection : ViewProjection;
float4x4 g_World;

texture	g_TextureDiffuse0 : Diffuse;
float colorMultiplier = 1.f;

sampler TextureDiffuse0Sampler = 
sampler_state
{
    Texture		= < g_TextureDiffuse0 >;    
    MipFilter	= LINEAR;
    MinFilter	= LINEAR;
    MagFilter	= LINEAR;
};

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

// random stable 3D noise
float3 hash33(float3 p3)
{
	p3 = frac(p3 * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz + 19.19);
    return -1.0 + 2.0 * frac(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

float simplex_noise(float3 p)
{
    float K1 = 0.333333333;
    float K2 = 0.166666667;
    
    float3 i = floor(p + (p.x + p.y + p.z) * K1);
    float3 d0 = p - (i - (i.x + i.y + i.z) * K2);
    
    float3 e = step((float3)0.0, d0 - d0.yzx);
	float3 i1 = e * (1.0 - e.zxy);
	float3 i2 = 1.0 - e.zxy * (1.0 - e);
    
    float3 d1 = d0 - (i1 - 1.0 * K2);
    float3 d2 = d0 - (i2 - 2.0 * K2);
    float3 d3 = d0 - (1.0 - 3.0 * K2);
    
    float4 h = max(0.6 - float4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
    float4 n = h * h * h * h * float4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)), dot(d2, hash33(i + i2)), dot(d3, hash33(i + 1.0)));
    
    return dot((float4)31.316, n);
}

float simplex_refine(float3 n, int iterations, float amplitude) {
	float total = 0.0;
	for (int i = 0; i < iterations; i++) {
		total += simplex_noise(n) * amplitude;
		n += n;
		amplitude *= 0.5;
	}
	return total;
}

float selfDotInv(float3 x)
{
	return rcp(1.0 + dot(x , x));
}

float2 rotate(float2 rotation, float rate)
{
	return float2(dot(rotation,  float2(cos(rate),  -sin(rate))), dot(rotation,  float2(sin(rate),  cos(rate))));
}

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
	oNormal = iPosition.xyz * 0.1;
    oColor0 = float4(1, 1, 1, 1) * colorMultiplier;
    oTexCoord0 = iTexCoord0;
}

void
RenderScenePS( 
	float3 iNormal : NORMAL,
	float4 iColor : COLOR,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oColor0 : COLOR0 ) 
{ 

	float distortWeight = selfDotInv(SRGBToLinear(tex2D(TextureDiffuse0Sampler, iTexCoord0)).rgb);

	float simplex = simplex_refine(iNormal * 4.0, distortWeight * 7.0 + 1.0, 0.5) * distortWeight;
	oColor0 = SRGBToLinear(tex2D(TextureDiffuse0Sampler, iTexCoord0 + float2(simplex, -simplex) * 0.00125));
	oColor0.rgb = oColor0.rgb + (simplex * oColor0.rgb) * selfDotInv(oColor0.rgb) * 0.25;
	oColor0 = LinearToSRGB(saturate(oColor0));
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_3_0 RenderSceneVS();
        PixelShader = NULL;
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
		AlphaTestEnable = TRUE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = INVSRCALPHA;            
		Texture[0] = < g_TextureDiffuse0 >;        
    }
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
		DestBlend = INVSRCALPHA;            
    }
}

