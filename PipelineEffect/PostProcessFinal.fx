// TODO write a proper bloom blend

//#define PUREVANILLA
#define CHROMATICABBERATION
#define VIGNETTE
#define TONEMAP
#define BLUR
#define GRAIN
#define MICROBLOOM

#define LINEARCOLOR			//proper bloom should be done in linear, to not wash out colors, but it comes with a math overhead
//#define CHEAPLINEARCOLOR	//minor but not insignificant speed bost.
//#define SIGMOID				// Use Sigmoid bright pass on bloom downsample

//#define DEBUGBLOOM

texture g_sceneTexture;
texture bloomTexture;

sampler sceneSampler = sampler_state{
	Texture	= <g_sceneTexture>;    
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
    AddressU = CLAMP;        
    AddressV = CLAMP;
    AddressW = CLAMP;};

sampler bloomSampler = sampler_state{
	Texture	= <bloomTexture>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = CLAMP;        
    AddressV = CLAMP;
    AddressW = CLAMP;};
	
float3 Square(float3 x)
{
	return x * x;
}
float Square(float x)
{
	return x * x;
}
//regularBloom
static const float mainBloomBoost = 0.65;

//specularBloom, note this is a rather expensive extra bloom for spcular light direct emissive backdrop stars and other minor details missed by main bloom
static const float bloomScale = 1.0; // scale of bloom! 0-1 range
static const float bloomTreshold = 0.1; // how low a value does blooming start
static const float bloomIntensity = 1.0; // intensity of the blooming.
static const int mSize = 5; // must be odd number. WARNING runs mSize^2 steps of full res buffer, so it's dont't run if you haven't got fast memory!!

// TODO, investigate if we can get the right value
static const float2 Res = float2(1920.0, 1080.0);
static const float2 ResInv = rcp(Res);
//static const float2 Res = 0.5/float2(1024.0, 768.0);

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

float Norm(float x, float sigma){
	return 0.39894 * exp(-0.5 * Square(x) / Square(sigma)) / sigma;
}


float3 hsv2rgb(float3 c)
{
    float3 rgb = saturate(abs(fmod(c.x * 6.0 + float3(0.0, 4.0, 2.0), 6.0) -3.0) -1.0);

	return c.z * lerp(1.0, rgb, c.y);
}

float3 rgb2hsv(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float luminance(float3 color)
{
	return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float3 Tonemap_Lottes(float3 x) {
    // Lottes 2016, "Advanced Techniques and Optimization of HDR Color Pipelines"
    const float a = 1.25;	//Was 1.6
    const float d = 0.977;
    const float hdrMax = 16.0;
    const float midIn = 0.0625; // 1/16
    const float midOut = 0.1;	//Was 0.267, then 0.1

    // Can be precomputed
    const float b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const float c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    return pow(x, (float3)a) / (pow(x, (float3)(a * d)) * (float3)b + (float3)c);
}

float Sigmoid(float x)
{
	//return 1.0 / (1.0 + (exp(-(x * 14.0 - 7.0))));
    return 1.0 / (1.0 + (exp(-(x - 0.5) * 14.0))); 
}

float3 Sigmoid (float3 x)
{
	return float3(Sigmoid(x.r), Sigmoid(x.g), Sigmoid(x.b));
}

float4 Sigmoid(float4 x)
{
	return float4(float3(Sigmoid(x.r), Sigmoid(x.g), Sigmoid(x.b)), 1.0);
}

float rand(float2 n){
	return frac(sin(dot(n.xy, float2(12.9898, 78.233))) * 43758.5453);
}

float4 MainPS(float2 t : TEXCOORD0) : COLOR
{
#ifdef DEBUGBLOOM
	return tex2D(bloomSampler, t);
#endif
#ifdef PUREVANILLA
	return tex2D(sceneSampler, t) + tex2D(bloomSampler, t);
#endif
#ifdef GRAIN
	float3 dither		= float3(rand(t), rand(t + 1.0), rand(t + 2.0)) - 0.5;
//	return float4(dither, 1);	
#else
	float3 dither		= (float3)0.0;
#endif	
	float2 centerUV		= t - 0.5;
	float vignette	 	= saturate(dot(centerUV, centerUV));
//	return float4(vignette.xxx, 1);
#ifdef CHROMATICABBERATION
	float3 ChromaWeight	= float3(0.005, 0.01, 0.015) * vignette;
	float4 s			= 0.0;
	s.r 				= tex2D(sceneSampler, t - centerUV * ChromaWeight.r).r;
	s.g					= tex2D(sceneSampler, t - centerUV * ChromaWeight.g).g;
	s.b					= tex2D(sceneSampler, t - centerUV * ChromaWeight.b).b;
	s.a 				= 1.0;
#else	
	float4 s 			= tex2D(sceneSampler, t);
#endif
#ifdef LINEARCOLOR
	s = SRGBToLinear(s);
#endif	
	
	float4 sb = 0.0;
#ifdef MICROBLOOM
	const int kSize = (mSize-1)/2;

	float kernel[mSize];
	
	float divider = 0.0;
	for (int i = 0; i <= kSize; ++i)
	{
		kernel[kSize+i] = kernel[kSize-i] = Norm(float(i), float(mSize));
	}
	
	for (int j = 0; j < mSize; ++j)
	{
		divider += kernel[j];
	}
	
	for (int k=-kSize; k <= kSize; ++k)
	{
		for (int h=-kSize; h <= kSize; ++h)
		{
			float currentSample = tex2D(sceneSampler, (t + float2(float(k),float(h)) / (Res / (bloomScale))));
			#ifdef LINEARCOLOR
				currentSample = SRGBToLinear(currentSample);
			#endif	
			#ifdef SIGMOID
				currentSample = Sigmoid(currentSample);
			#endif

			sb += kernel[kSize+h] * kernel[kSize+k] * currentSample;	
		}		
	}

	sb /= Square(divider);

	// color correct and blend
	sb = max(0.0, SRGBToLinear(sb) * bloomIntensity - bloomTreshold);
		
	
#endif
	

	float4 b 			= tex2D(bloomSampler, t);
	#ifdef LINEARCOLOR
		b = SRGBToLinear(b);
	#endif
		b *= mainBloomBoost;
	
	float4 c 			= 0;
		   c 			= s + b + sb;

#ifdef VIGNETTE
    c /= (1.0 + vignette);	
#endif

#ifdef GRAIN
	c.rgb *= (1.0 + dither * 0.008);
#endif

#ifdef TONEMAP
	float l = luminance(c.rgb);
//	c.rgb = hsv2rgb(rgb2hsv(c.rgb * float3(1.0, 1.0 + l * 0.25, 1.0 + l * 0.5)));
	c.rgb = Tonemap_Lottes(c.rgb);
#else
	c = float4(saturate(c.rgb), 1.0);
#endif
	#ifdef LINEARCOLOR
	return LinearToSRGB(float4(c.rgb, 1.0));
#else	
	return c;
#endif		
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
		VertexShader = NULL;
        PixelShader = compile ps_3_0 MainPS();
        AlphaBlendEnable = false;
    }
}

