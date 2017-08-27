float4x4 g_World : World;
float4x4 g_WorldViewProjection : WorldViewProjection;
float4x4 g_View;

texture	g_TextureDiffuse0 : Diffuse;
texture	g_TextureNormal;
texture g_TextureTeamColor;
texture	g_TextureSelfIllumination;
texture	g_TextureEnvironmentCube : Environment;
texture g_EnvironmentIllumination : Environment;

float4 g_Light_AmbientLite : Ambient;
float4 g_Light_AmbientDark : Ambient;

float3 g_Light0_Position: Position = float3( 0.f, 0.f, 0.f );
float4 g_Light0_DiffuseLite: Diffuse = float4( 1.f, 1.f, 1.f, 1.f );
float4 g_Light0_Specular;

float g_MaterialGlossiness;
float4 g_TeamColor;
float minShadow = .0f;

sampler TextureColorSampler = sampler_state{
    Texture = <g_TextureDiffuse0>;
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

sampler TextureNormalSampler = sampler_state{
    Texture = <g_TextureNormal>;
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

sampler TextureDataSampler = sampler_state{
    Texture = <g_TextureSelfIllumination>;    
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

samplerCUBE TextureEnvironmentCubeSampler = sampler_state{
    Texture = <g_TextureEnvironmentCube>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
	 
};

samplerCUBE EnvironmentIlluminationCubeSampler = sampler_state{
    Texture = <g_EnvironmentIllumination>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;

};

struct VsOutput
{
	float4 Position	: POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 LightTangent : TEXCOORD1;
	float3 ViewTangent : TEXCOORD2;	
};

VsOutput RenderSceneVS( 
	float3 position : POSITION, 
	float3 normal : NORMAL,
	float3 tangent : TANGENT,
	float2 texCoord : TEXCOORD0)
{
	VsOutput output;
	
	output.Position = mul(float4(position, 1.0f), g_WorldViewProjection);
	output.TexCoord = texCoord;	

	float3 tangentInWorldSpace = normalize(mul(tangent, (float3x3)g_World));
	float3 normalInWorldSpace = normalize(mul(normal, (float3x3)g_World));
	float3 biTangentInWorldSpace = cross(normalInWorldSpace, tangentInWorldSpace);
    float3x3 tangentMatrix = transpose(float3x3(tangentInWorldSpace, biTangentInWorldSpace, normalInWorldSpace));
    
	float3 positionInWorldSpace = mul(float4(position, 1.f), g_World).xyz;
	float3 positionInTangentSpace = mul(positionInWorldSpace, tangentMatrix);
	output.ViewTangent = normalize(-positionInTangentSpace);
         
	float3 lightInTangentSpace = mul(g_Light0_Position, tangentMatrix);
	output.LightTangent = normalize(lightInTangentSpace - positionInTangentSpace);
   
    return output;
}

float4 SRGBToLinear(float4 color)
{
	return color;

	//When external colors and the data texture are redone this can be reenabled.
	//return float4(color.rgb * (color.rgb * (color.rgb * 0.305306011f + 0.682171111f) + 0.012522878f), color.a);
}

float4 LinearToSRGB(float4 color)
{
	return color;

	//When external colors and the data texture are redone this can be reenabled.
	//float3 S1 = sqrt(color.rgb);
	//float3 S2 = sqrt(S1);
	//float3 S3 = sqrt(S2);
	//return float4(0.662002687 * S1 + 0.684122060 * S2 - 0.323583601 * S3 - 0.225411470 * color.rgb, color.a);
}

float4 GetColorWithTeamColorSample(float4 colorSample)
{
	float4 linearTeamColor = SRGBToLinear(g_TeamColor);
	float teamColorScalar = (colorSample.a * linearTeamColor.a); 
	
	float4 colorWithTeamColor = colorSample * (1.f - teamColorScalar);
	colorWithTeamColor += (linearTeamColor * teamColorScalar);
	colorWithTeamColor.a = colorSample.a;

	return colorWithTeamColor;
}

float3 GetNormalInTangentSpace(float2 texCoord)
{
	//using nvidia's DXT5_NM format:
	//http://discuss.microsoft.com/SCRIPTS/WA-MSD.EXE?A2=ind0507D&L=DIRECTXDEV&P=R1929&I=-3
	float4 sample = 2.f * tex2D(TextureNormalSampler, texCoord) - 1.f;
	float x = sample.a;
	float y = sample.g;
	float z = sqrt(1 - x * x - y * y);

	//NOTE: have to renormalize tangent vectors as linear interpolation screws them up.
	return normalize(float3(x,y,z));
}

float4 GetAmbientLightColor(float3 normal)
{
    float4 ambSample = SRGBToLinear(texCUBE(EnvironmentIlluminationCubeSampler, normal));
	ambSample.a = 1.f;	
    return ambSample;
}

float4 GetDiffuseLightColor(float3 incidence, float3 normal, float4 lightColor)
{
	float diffuseScalar = clamp(dot(incidence, normal), minShadow, 1.f);
	return diffuseScalar * lightColor;
}

float4 GetSpecularColor(float3 light, float3 normal, float3 view, float glossScalar)
{
	float3 h = normalize(light + view); //half angle

    float NDotH = dot(normal, h);
    float HDotV = dot(h, view);
    float NDotV = dot(normal, view);
    float NDotL = dot(normal, light);
	
	//Geometretic attenuation (self masking)
    float selfMask = clamp(min(1, min(2 * (NDotH * NDotV) / HDotV, 2 * (NDotH * NDotL) / HDotV)), .001f, 1.f);

	float i = pow(clamp(NDotH, 0.0001f, 1.f), g_MaterialGlossiness) * glossScalar; //pow(0, x) is bugged so keep it at a small non-zero value.
	
	float4 linearSpecular = SRGBToLinear(g_Light0_Specular);
	return i * selfMask * linearSpecular;
}

float4 GetEnvironmentColor(float3 view, float envScalar)
{
    float4 envSample = SRGBToLinear(texCUBE(TextureEnvironmentCubeSampler, view));    
	envSample.a = 1.f;
    return (envSample * envScalar);
}

float4 GetFinalPixelColor(float2 texCoord, float3 lightTangent, float3 viewTangent)
{   
	float4 colorSample = SRGBToLinear(tex2D(TextureColorSampler, texCoord));
	colorSample = GetColorWithTeamColorSample(colorSample);	
	float4 dataSample = tex2D(TextureDataSampler, texCoord);	
		
	float3 normalTangent = GetNormalInTangentSpace(texCoord);
	
	float specScalar = dataSample.r;
	float4 spec = GetSpecularColor(lightTangent, normalTangent, viewTangent, specScalar);	

	float4 amb = GetAmbientLightColor(normalTangent) * colorSample;

	float4 linearDiffuseLite = SRGBToLinear(g_Light0_DiffuseLite);
	float4 diff = GetDiffuseLightColor(lightTangent, normalTangent, linearDiffuseLite) * colorSample;
	
	float envScalar = dataSample.b;
	float4 env = GetEnvironmentColor(viewTangent, envScalar);
	
	float4 finalColor = amb + diff + env + spec;
	
	float selfIllumLightScalar = dataSample.g;
	finalColor = selfIllumLightScalar * colorSample + (1.f - selfIllumLightScalar) * finalColor;
		
	return LinearToSRGB(finalColor);
}

float4 RenderScenePS(VsOutput input) : COLOR0
{ 
	return GetFinalPixelColor(input.TexCoord, input.LightTangent, input.ViewTangent);
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_2_0 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS();
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
}
