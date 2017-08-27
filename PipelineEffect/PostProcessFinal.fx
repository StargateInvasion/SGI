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
    
float4 MainPS(float2 t : TEXCOORD0) : COLOR
{ 
	float4 s = tex2D(sceneSampler, t);
	float4 b = tex2D(bloomSampler, t);
	float4 c = s + b;
    return c;
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
		VertexShader = NULL;
        PixelShader = compile ps_2_0 MainPS();
        AlphaBlendEnable = false;
    }
}

