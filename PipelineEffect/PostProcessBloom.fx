#define NOJITTERBLOOM 		//warning this needs a lot more samples, so performance might be influenced
#define LINEARCOLOR			//proper bloom should be done in linear, to not wash out colors, but it comes with a math overhead
//#define CHEAPLINEARCOLOR	//minor but not insignificant speed bost.
#define SIGMOID				// Use Sigmoid bright pass on bloom downsample
#define WIDEBLOOM			//increases the bloom to 64 taps - note the texture is 1/8th, so that's a lot!
#define SPIRALBLUR			//trigonomically heavy, but sample wise a lot more conservative radial gaussian blur function
#define REDSHIFT			//ONLY works on spiral blur. Greatly improves monocrhomatic bloom
#define BLOOMBOOST			//uses below constant to boost bloom without ever bleeding it out to white
const float bloomBoost = 32.0;

float4 sampleWeights[16];
float2 sampleOffsets[16];

texture inputTexture;

sampler inputSampler = sampler_state{
	Texture	= <inputTexture>;    
    MipFilter = LINEAR; // point has got to be faster, and it doesn't matter in this case
    MinFilter = LINEAR; // point has got to be faster, and it doesn't matter in this case
    MagFilter = LINEAR; // point has got to be faster, and it doesn't matter in this case
    AddressU = CLAMP;        
    AddressV = CLAMP;
    AddressW = CLAMP;
};

float3 Square(float3 x)
{
	return x * x;
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

float Sigmoid(float x)
{
    return 1.0 / (1.0 + exp((x * -14.0 + 7.0))); 
}
float3 Sigmoid (float3 x)
{
	return float3(Sigmoid(x.r), Sigmoid(x.g), Sigmoid(x.b));
}
float4 Sigmoid(float4 x)
{
	return float4(float3(Sigmoid(x.r), Sigmoid(x.g), Sigmoid(x.b)), 1.0);
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

float4 DownSamplePS(in float2 texCoord : TEXCOORD0) : COLOR
{
    float4 sample = 0.0f;	
	
#ifdef NOJITTERBLOOM
	// Downsample buffer is 1/8th the screen resolution, which means we need 64 samples for a stable downsample
	// Index 11 holds the texel size, so we can reverse that to get a new offset
	float2 fullRes = (1.0/sampleOffsets[11]) * 8.0;
	float2 newOffset = 1.0/fullRes;
	float2 restOffset = -newOffset * 4.0;
	float2 currentOffset = -newOffset * 4.0;
	float4 currentSample = 0;
	const int mSize = 64;
	const int kSize = 8;
	
	for (int i= 0; i < kSize; ++i)
	{
		currentOffset.x += newOffset.x;
		for (int j= 0; j < kSize; ++j)
		{
			currentOffset.y += newOffset.y;
			#ifdef LINEARCOLOR
				currentSample = SRGBToLinear(tex2D(inputSampler, texCoord + currentOffset));
			#else
				currentSample = tex2D(inputSampler, texCoord + currentOffset);
			#endif
			#ifdef SIGMOID
				currentSample = Sigmoid(currentSample);
			#endif	
			sample += currentSample;
		}
		currentOffset.y = restOffset.y;
	}
	sample /= mSize;
#else
	for (int i = 0; i < 12; i++)
	{
		#ifdef LINEARCOLOR
		sample += sampleWeights[i] * SRGBToLinear(tex2D(inputSampler, texCoord + sampleOffsets[i]));
		#else
		sample += sampleWeights[i] * tex2D(inputSampler, texCoord + sampleOffsets[i]);
		#endif		
	}	
#endif
	#ifdef LINEARCOLOR
		sample = LinearToSRGB(sample);
	#endif
	#ifdef BLOOMBOOST	
		return float4(Square(Square(1.0 - rcp(1.0 + sample.rgb * bloomBoost))), 1);
	#else
		return sample;
	#endif
}

float SmoothStepHardcoded(float x)
{
	return x * x * (3.0 - x * 2.0);
}

float normpdf(float x, float sigma)
{
	return 0.39894 * exp(-0.5 * x * x / (sigma * sigma)) / sigma;
}

float4 BlurPS(in float2 texCoord : TEXCOORD0) : COLOR
{
	float4 sample = float4(0.0, 0.0, 0.0, 1.0);
#ifdef SPIRALBLUR
	float2 aspectRatio;
	// work around
	if(sampleOffsets[1].x > 0.0)
	{
		aspectRatio = float2(1.0, 0.01 / sampleOffsets[1].x);
	}
	else
	{
		aspectRatio = float2(0.01 / sampleOffsets[1].y, 1.0);
	}

	float Distance = 0.08;	
	float DistanceSteps = 16.0;
	float RadialSteps = 8.0;
	float RadialOffset = 0.62;
	float KernelPower = 1.0;
	
	
	float3 curColor = 0;
	float3 sumColor = 0;
	float2 NewUV = texCoord;
	int i = 0;
	float StepSize = Distance / (int)DistanceSteps;
	float curDistance = 0;
	float2 CurOffset = 0;
	float SubOffset = 0;
	float TwoPi = 6.283185;
	float accumdist = 0;
	
	if(DistanceSteps < 1)
	{
		sample = SRGBToLinear(tex2D(inputSampler, texCoord));		
	}
	else
	{
		while(i < (int) DistanceSteps)
		{
			curDistance += StepSize;
			for(int j = 0; j < (int) RadialSteps; j++)
			{
				SubOffset += 1;
				CurOffset.x = cos(TwoPi * (SubOffset / RadialSteps));
				CurOffset.y = sin(TwoPi * (SubOffset / RadialSteps));
				NewUV = texCoord + CurOffset * curDistance * aspectRatio;

				if((abs(NewUV.x - 0.5) > 0.5) || (abs(NewUV.y - 0.5) > 0.5))
					continue;
				float DistCurved = pow(curDistance, KernelPower);
				#ifdef REDSHIFT
					float4 DistFalloff = float4(lerp((float3)1.0, float3(1.15,1.0, 0.9), saturate(curDistance)) * DistCurved, 1.0);
				#else
					float4 DistFalloff = float4(DistCurved, DistCurved, DistCurved, 1.0);
				#endif
				//float distpow = SmoothStepHardcoded(CurDistance);

				#ifdef LINEARCOLOR
					curColor = SRGBToLinear(tex2D(inputSampler, NewUV));				
				#else
					curColor = tex2D(inputSampler, NewUV);
				#endif	

				sumColor += curColor * DistFalloff;
				accumdist += curDistance;
			}
			SubOffset += RadialOffset;
			i++;
		}
		sumColor /= accumdist;
		sample = float4(sumColor, 1.0);
	}
#else
    // Perform a one-directional gaussian blur
    for (int i = 0; i < 15; i++)
    {
        samplePosition = texCoord + sampleOffsets[i];
        color = SRGBToLinear(tex2D(inputSampler, samplePosition));
        sample += sampleWeights[i] * color;
    }
#endif

	#ifdef LINEARCOLOR
		return LinearToSRGB(sample);
	#else
		return sample;
	#endif
}

technique RenderWithPixelShader
{
    pass DownSamplePass
    {
		VertexShader = NULL;
        PixelShader = compile ps_3_0 DownSamplePS();
        AlphaBlendEnable = false;
	}

	pass HBlurPass
	{
		VertexShader = NULL;
        PixelShader = compile ps_3_0 BlurPS();
        AlphaBlendEnable = false;
	}
	
	pass VBlurPass
	{
		VertexShader = NULL;
        PixelShader = compile ps_3_0 BlurPS();
        AlphaBlendEnable = false;
	}
}
