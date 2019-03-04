#define PBR 

float4x4 g_World : World;
float4x4 g_WorldViewProjection : WorldViewProjection;

texture	g_TextureDiffuse0 : Diffuse;
texture g_TextureTeamColor;
texture	g_TextureSelfIllumination;
float4 g_TeamColor;
float colorMultiplier = 1.f;

sampler TextureColorSampler = 
sampler_state
{
    Texture = < g_TextureDiffuse0 >;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler TextureDataSampler = 
sampler_state
{
    Texture = < g_TextureSelfIllumination >;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

struct VsOutput
{
	float4 Position	: POSITION;
	float2 TexCoord0 : TEXCOORD0;
};

VsOutput
RenderSceneVS( 
	float3 iPosition : POSITION, 
	float3 iNormal : NORMAL,
	float3 iTangent : TANGENT,
	float2 iTexCoord0 : TEXCOORD0 )
{
	VsOutput o;  
	
	//Final Position
	o.Position = mul( float4( iPosition, 1.0f ), g_WorldViewProjection );
	
	//Texture Coordinates
    o.TexCoord0 = iTexCoord0; 
          
    return o;
}

float4 GetPixelColor( float2 iTexCoord )
{
	float4 colorSample = tex2D(TextureColorSampler, iTexCoord); 
    float4 dataSample = tex2D(TextureDataSampler, iTexCoord);
    
    //Team Color
    float4 teamColorScalar = (colorSample.a * g_TeamColor.a); 
	colorSample *= (1.f - teamColorScalar);
	colorSample += (g_TeamColor * teamColorScalar);

	//Self Illumination
	float selfIlluminationScalar = dataSample.g;

#ifdef PBR	
	//Bloom
	float bloomScalar = dataSample.b;
#else
	float bloomScalar = dataSample.a;
#endif
	float4 oColor = colorSample * colorMultiplier * bloomScalar;
	return oColor;
}

void
RenderScenePS( 
	VsOutput i,
	out float4 oColor0 : COLOR0 ) 
{ 
	oColor0 = GetPixelColor( i.TexCoord0 );
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_1_1 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS();
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
}
