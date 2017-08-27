float4 sampleWeights[16];
float2 sampleOffsets[16];

texture inputTexture;

sampler inputSampler = sampler_state{
	Texture	= <inputTexture>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = CLAMP;        
    AddressV = CLAMP;
    AddressW = CLAMP;
};

float4 DownSamplePS(in float2 texCoord : TEXCOORD0) : COLOR
{
    float4 sample = 0.0f;
	for (int i = 0; i < 12; i++)
	{
		sample += sampleWeights[i] * tex2D(inputSampler, texCoord + sampleOffsets[i]);
	}
	return sample;
}

float4 BlurPS(in float2 texCoord : TEXCOORD0) : COLOR
{
    float4 sample = 0.0f;
    float4 color = 0.0f;
    float2 samplePosition;
    
    // Perform a one-directional gaussian blur
    for (int i = 0; i < 15; i++)
    {
        samplePosition = texCoord + sampleOffsets[i];
        color = tex2D(inputSampler, samplePosition);
        sample += sampleWeights[i] * color;
    }
    
    return sample;
}

technique RenderWithPixelShader
{
    pass DownSamplePass
    {
		VertexShader = NULL;
        PixelShader = compile ps_2_0 DownSamplePS();
        AlphaBlendEnable = false;
	}

	pass HBlurPass
	{
		VertexShader = NULL;
        PixelShader = compile ps_2_0 BlurPS();
        AlphaBlendEnable = false;
	}
	
	pass VBlurPass
	{
		VertexShader = NULL;
        PixelShader = compile ps_2_0 BlurPS();
        AlphaBlendEnable = false;
	}
}
