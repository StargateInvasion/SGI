float4x4 g_World : World;
float4x4 g_WorldViewProjection : WorldViewProjection;

texture	g_TextureDiffuse0 : Diffuse;
texture	g_TextureNormal;
texture	g_TextureSelfIllumination;
texture	g_TextureEnvironmentCube : Environment;

float4 g_Light_AmbientLite: Ambient;
float4 g_Light_AmbientDark;

float3 g_Light0_Position: Position = float3( 0.f, 0.f, 0.f );
float4 g_Light0_DiffuseLite: Diffuse = float4( 1.f, 1.f, 1.f, 1.f );
float4 g_Light0_DiffuseDark;
float4 g_Light0_Specular;

float g_MaterialGlossiness = 1.f;

float g_MinShadow;

#ifdef IsDebug
float DiffuseScalar = 1;
float AmbientScalar = 1;
float SelfIllumScalar = 1;
float SpecularScalar = 1;
float EnvironmentScalar = 1;
#endif

sampler TextureColorSampler = sampler_state{
    Texture = <g_TextureDiffuse0>;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler TextureNormalSampler = sampler_state{
    Texture = <g_TextureNormal>;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler TextureDataSampler = sampler_state{
    Texture = <g_TextureSelfIllumination>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
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

struct VsOutputSimple
{
	float4 Position	: POSITION;
	float4 Color : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

VsOutputSimple RenderSceneVSSimple(
	float3 position : POSITION, 
	float3 normal : NORMAL,
	float2 texCoord : TEXCOORD0)
{
	VsOutputSimple output;

	output.Position = mul(float4(position, 1.f), g_WorldViewProjection);
	output.TexCoord = texCoord;
	
	float3 posLightInLocalSpace = mul(float4(g_Light0_Position, 1.f), transpose(g_World)).xyz;
	float3 vecLightInLocalSpace = normalize(posLightInLocalSpace - position);
    float4 diffuse = g_Light0_DiffuseLite * max(dot(vecLightInLocalSpace, normal), 0.f);
	float4 ambient = g_Light_AmbientLite;
	output.Color = diffuse + ambient;
	
	return output;
}

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

float3 GetNormalInTangentSpace(float2 texCoord)
{
	//using nvidia's DXT5_NM format:
	//http://discuss.microsoft.com/SCRIPTS/WA-MSD.EXE?A2=ind0507D&L=DIRECTXDEV&P=R1929&I=-3
	float4 sample = 2.f * tex2D(TextureNormalSampler, texCoord) - 1.f;
	float x = sample.a;
	float y = sample.g;
	float z = sqrt(1 - x * x - y * y);
	return normalize(float3(x,y,z));
}

float4 GetSelfIllumLightScalar(float2 texCoord, float4 dataSample)
{
    return dataSample.g;
}

float4 GetSpecularColor(float3 light, float3 normal, float3 view, float4 colorSample)
{
	float cosang = clamp(dot(reflect(-light, normal), view), 0.00001f, 0.95f);
	float glossScalar = colorSample.a;
	float specularScalar = pow(cosang, g_MaterialGlossiness) * glossScalar;
	return (g_Light0_Specular * specularScalar);
}

float4 GetEnvironmentColor(float3 view, float4 dataSample)
{
    float4 sample = texCUBE(TextureEnvironmentCubeSampler, view);
    float x = dataSample.b;
    return (sample * x);
}

float4 GetLightColor(float3 incidence, float3 normal, float4 liteLightColor, float4 darkLightColor)
{
	float dotProduct = max(dot(incidence, normal), 0.f);	
	float lerpPercent = 1.f - clamp(pow(dotProduct, 5.f), 0.f, 1.f);
	
	float blackThreshold = .65f;
	float colorLerpPercent = min(lerpPercent / blackThreshold, 1.f);
		
	float blackRange = max(lerpPercent - blackThreshold, 0.f);
	float blackLerpPercent = blackRange / (1.f - blackThreshold);

	float4 newColor = lerp(liteLightColor, darkLightColor, colorLerpPercent);
	
	#ifndef IsDebug
	return lerp(newColor, g_MinShadow, blackLerpPercent);	
	#else
	return lerp(newColor, 0.f, blackLerpPercent);	
	#endif
}

float4 GetFinalPixelColor(float2 texCoord, float3 lightTangent, float3 viewTangent)
{
	float4 colorSample = tex2D(TextureColorSampler, texCoord);
	float4 dataSample = tex2D(TextureDataSampler, texCoord);

	//NOTE: have to renormalize tangent vectors as linear interpolation screws them up.
	float3 normalTangent = GetNormalInTangentSpace(texCoord);
	
	float4 finalColor = 0.f;
	
	//#ifndef IsDebug
		finalColor += colorSample * GetLightColor(lightTangent, normalTangent, g_Light0_DiffuseLite, g_Light0_DiffuseDark);
		finalColor += colorSample * GetLightColor(viewTangent, normalTangent, g_Light_AmbientLite, g_Light_AmbientDark);		
		finalColor += colorSample * 2.f * GetSpecularColor(lightTangent, normalTangent, viewTangent, colorSample);
		finalColor += GetEnvironmentColor(viewTangent, dataSample);
		
		float selfIllumLightScalar = GetSelfIllumLightScalar(texCoord, dataSample);
		finalColor = selfIllumLightScalar * colorSample + (1.f - selfIllumLightScalar) * finalColor;
	//#else
	//	finalColor += colorSample * GetLightColor(lightTangent, normalTangent, g_Light0_DiffuseLite, g_Light0_DiffuseDark) * DiffuseScalar;
	//	finalColor += colorSample * GetLightColor(viewTangent, normalTangent, g_Light_AmbientLite, g_Light_AmbientDark) * AmbientScalar;
	//	finalColor += GetSpecularColor(lightTangent, normalTangent, viewTangent, colorSample) * SpecularScalar;
	//	finalColor += GetEnvironmentColor(viewTangent, dataSample) * EnvironmentScalar;	
		
	//	//NOTE: SelfIllumScalar ignored, too many operations for shader to handle...
	//	float selfIllumLightScalar = GetSelfIllumLightScalar(texCoord, dataSample) * SelfIllumScalar;
	//	finalColor = selfIllumLightScalar * colorSample + (1.f - selfIllumLightScalar) * finalColor;
	//#endif

	return finalColor;
}

float4 RenderScenePS(VsOutput input) : COLOR0
{ 
	return GetFinalPixelColor(input.TexCoord, input.LightTangent, input.ViewTangent);
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVSSimple();
        PixelShader = NULL;
		Texture[0] = <g_TextureDiffuse0>;
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
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
