texture	g_TextureDiffuse0 : Diffuse;
texture g_TextureSceneSource;
float4 g_ViewportArea; //format = left, width, top, height

sampler SourceSampler = 
sampler_state 
{
    texture = < g_TextureSceneSource >;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

struct VS_OUTPUT
{
   	float4 Position : POSITION;
    float2 TexCoord : TEXCOORD0;
};

VS_OUTPUT 
VS_Quad(
	float4 Position : POSITION, 
	float2 TexCoord : TEXCOORD0 )
{
	VS_OUTPUT OUT;
    OUT.Position = Position;
    OUT.TexCoord = TexCoord;
    return OUT;
}

float4 PS_BandboxCalculate(VS_OUTPUT IN) : COLOR
{   
	float2 sampleTexCoord = float2(
		g_ViewportArea[0] + IN.TexCoord.x * g_ViewportArea[1],
		g_ViewportArea[2] + IN.TexCoord.y * g_ViewportArea[3]);
	float4 sample = tex2D(SourceSampler, sampleTexCoord);
	float1 intensity = 
		(0.3 * sample.r) + 
		(0.59 * sample.g) + 
		(0.14 * sample.b);
	float1 intensityScale = .5;
	intensity = intensity * intensityScale;
	float minIntensity = .05;
	float maxIntensity = .2;
	intensity = max(minIntensity, intensity);
	intensity = min(maxIntensity, intensity);
	float4 output = float4(intensity, intensity, intensity, 1.f);
	return output;
}

float4 PS_BandboxWrite(VS_OUTPUT IN) : COLOR
{   
	float2 sampleTexCoord = float2(
		(IN.TexCoord.x - g_ViewportArea[0]) * g_ViewportArea[1],
		(IN.TexCoord.y - g_ViewportArea[2]) * g_ViewportArea[3]);
	float4 sample = tex2D(SourceSampler, sampleTexCoord);

//fun effect
//	float x = length(float2(sampleTexCoord.x, sampleTexCoord.y)) / length(float2(1.f, 1.f));
//	sample = float4(x, x, x, 1.f);
	
	return sample;
}

technique RenderWithPixelShader
{
    pass Pass0
    {   	    
		CullMode = none;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_2_0 VS_Quad();
		PixelShader = compile ps_2_0 PS_BandboxCalculate();
    }
    
    pass Pass1
    {   	    
		CullMode = none;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_2_0 VS_Quad();
		PixelShader= compile ps_2_0 PS_BandboxWrite();
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;     		
    }    
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	    
		VertexShader = NULL;
		PixelShader = NULL;
    
        Lighting = FALSE;
        SpecularEnable = FALSE;
        ColorVertex = TRUE;
        DiffuseMaterialSource = COLOR1;

        ZEnable = FALSE;
        ZWriteEnable = FALSE;   

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;             
    }
}

