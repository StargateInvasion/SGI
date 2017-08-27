texture	g_TextureDiffuse0 : Diffuse;
float4 g_channelMultipliers = float4(1.f, 0.f, 0.f, 0.f);

sampler s_Diffuse0 = 
sampler_state 
{
    texture = < g_TextureDiffuse0 >;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MipFilter = NONE;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

struct VS_OUTPUT
{
   	float4 Position : POSITION;
    float2 TexCoord : TEXCOORD0;
};

float4 ShowChannelPS(VS_OUTPUT IN, uniform sampler2D diffuseSampler ) : COLOR
{   
	float4 s = tex2D( diffuseSampler, IN.TexCoord );
	float c = dot(s, g_channelMultipliers);
	float4 o = float4(c, c, c, 1.f);
	return o;
}

technique RenderWithPixelShader
{
    pass Pass0
    {   	    
		VertexShader = NULL;
		PixelShader	= compile ps_2_0 ShowChannelPS(s_Diffuse0);
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


