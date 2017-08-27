float2 g_SampleOffsets[ShadowSampleCount];
float g_SampleWeights[ShadowSampleCount];
texture g_ShadowTexture;

sampler TextureShadowSampler = sampler_state
{
	Texture = <g_ShadowTexture>;
	AddressU = CLAMP;
	AddressV = CLAMP;
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

float4 PSBlurShadow(float2 texCoord : TEXCOORD0) : COLOR0
{
	float2 data = 0.f;
	
	for(int i = 0; i < ShadowSampleCount; ++i)
	{
		float4 sample = tex2D(TextureShadowSampler, texCoord + g_SampleOffsets[i].xy) * g_SampleWeights[i];
		data += sample.rg;
	}
	
	return float4(data.x, data.y, 0.f, 1.f);
}

technique RenderWithPixelShader
{
    pass p0
    {
        PixelShader = compile ps_2_0 PSBlurShadow();
    }
}