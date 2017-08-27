float4x4		g_World					: World;
float4x4		g_WorldViewProjection	: WorldViewProjection;

texture	g_TextureDiffuse0 : Diffuse;
texture	g_TextureSelfIllumination;
texture g_TextureDiffuse2 : Diffuse;
texture g_TextureNoise3D;

float4 g_Light_AmbientLite: Ambient;
float4 g_Light_AmbientDark;

float3 g_Light0_Position: Position = float3( 0.f, 0.f, 0.f );
float4 g_Light0_DiffuseLite: Diffuse = float4( 1.f, 1.f, 1.f, 1.f );
float4 g_Light0_DiffuseDark;
float4 g_Light0_Specular;

float4 g_MaterialAmbient:Ambient;
float4 g_MaterialDiffuse:Diffuse;
float g_MaterialGlossiness = 50;
float4 g_GlowColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
float4 g_CloudColor = float4(1.0f, 1.0f, 1.0f, 1.0f);

float g_Time;
float g_Radius;

#ifdef IsDebug
float DiffuseScalar = 1;
float AmbientScalar = 1;
float SelfIllumScalar = 1;
float SpecularScalar = 1;
float EnvironmentScalar = 1;
float TeamColorScalar = 1;
#endif

sampler TextureColorSampler = sampler_state
{
    Texture	= <g_TextureDiffuse0>;    
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

sampler TextureDataSampler = sampler_state
{
    Texture = <g_TextureSelfIllumination>;    
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

sampler NoiseSampler = sampler_state 
{
    texture = <g_TextureNoise3D>;
    AddressU = WRAP;        
    AddressV = WRAP;
	AddressW = WRAP;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler CloudLayerSampler = sampler_state
{
    Texture	= <g_TextureDiffuse2>;    
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

void
RenderSceneVSSimple(
	float3 iPosition : POSITION, 
	float3 iNormal : NORMAL,
	float2 iTexCoord0 : TEXCOORD0,
	out float4 oPosition : POSITION,
	out float4 oColor : COLOR0,
	out float2 oTexCoord : TEXCOORD0)
{
	oPosition = mul(float4(iPosition, 1.f), g_WorldViewProjection);
	
	float3 lightPositionLocal = mul(g_Light0_Position, transpose((float3x3)g_World));
	float3 vToLightLocal = normalize(lightPositionLocal - iPosition);

    float4 diffuse = g_MaterialDiffuse * g_Light0_DiffuseLite * max(dot(vToLightLocal, iNormal), 0.f);
	float4 ambient = g_MaterialAmbient * g_Light_AmbientLite;
	oColor = diffuse + ambient;
		
	oTexCoord = iTexCoord0;
}

struct VsSceneOutput
{
	float4 position	: POSITION;
	float2 texCoord : TEXCOORD0;
	float3 normal : TEXCOORD1;
	float3 lightDir : TEXCOORD2;
	float3 viewDir : TEXCOORD3;
};

VsSceneOutput RenderSceneVS(
	float3 position : POSITION, 
	float3 normal : NORMAL,
	float2 texCoord : TEXCOORD0)	
{
	VsSceneOutput output;  
	
	output.position = mul(float4(position, 1.0f), g_WorldViewProjection);
    output.texCoord = texCoord; 
	output.normal = mul(normal, (float3x3)g_World);
    output.lightDir = normalize(g_Light0_Position - output.position);
	float3 positionInWorldSpace = mul(float4(position, 1.f), g_World).xyz;
    output.viewDir = normalize(-positionInWorldSpace);
	
    return output;
}

float4 GetSpecularColor(float3 light, float3 normal, float3 view, float4 colorSample)
{
	float cosang = clamp(dot(reflect(-light, normal), view), 0.00001f, 0.95f);
	float glossScalar = colorSample.a;
	float specularScalar = pow(cosang, g_MaterialGlossiness) * glossScalar;
	return (g_Light0_Specular * specularScalar);
}

float4 GetLightColor(float dotLight, float exponent, float blackThreshold, float invertPercentage, float4 liteLightColor, float4 darkLightColor)
{
	float lerpPercent = pow(max(dotLight, 0.f), exponent);
	lerpPercent = lerp(lerpPercent, 1.f - lerpPercent, invertPercentage);
	
	float colorLerpPercent = min(lerpPercent / blackThreshold, 1.f);
		
	float blackRange = max(lerpPercent - blackThreshold, 0.f);
	float blackLerpPercent = blackRange / (1.f - blackThreshold);

	float4 newColor = lerp(liteLightColor, darkLightColor, colorLerpPercent);
	return lerp(newColor, 0.0f, blackLerpPercent);	
}

float4 RenderScenePS(VsSceneOutput input) : COLOR0
{ 
	float4 lightSideSample = tex2D(TextureColorSampler, input.texCoord);
	float4 darkSideSample = tex2D(TextureDataSampler, input.texCoord);

	float4 finalColor = 0.f;
	
	float dotLight = dot(input.lightDir, input.normal);

	#ifndef IsDebug	
		finalColor += lightSideSample * GetLightColor(dotLight, 1.25f, .25f, 1.f, g_Light0_DiffuseLite, g_Light0_DiffuseDark);
		finalColor += lightSideSample * GetLightColor(-dotLight, 1.25f, .25f, 0.f, g_Light_AmbientLite, g_Light_AmbientDark);
		finalColor += darkSideSample * GetLightColor(dotLight, 1.25f, .25f, 0.f, 1.f, 0.f);
		finalColor += GetSpecularColor(input.lightDir, input.normal, input.viewDir, lightSideSample);
	#else	
		finalColor += lightSideSample * GetLightColor(dotLight, 1.f, .25f, 1.f, g_Light0_DiffuseLite, g_Light0_DiffuseDark) * DiffuseScalar;
		finalColor += lightSideSample * GetLightColor(-dotLight, 1.25f, .25f, 0.f, g_Light_AmbientLite, g_Light_AmbientDark) * AmbientScalar;
		finalColor += darkSideSample * GetLightColor(dotLight, 1.25f, .25f, 0.f, 1.f, 0.f) * SelfIllumScalar;
		finalColor += GetSpecularColor(input.lightDir, input.normal, input.viewDir, lightSideSample) * SpecularScalar *2;
	#endif
	
	return finalColor;
}

struct VsCloudsOutput
{
	float4 Position: POSITION;
	float2 TexCoord0: TEXCOORD0;
	float3 Light: TEXCOORD1;
	float3 Normal: TEXCOORD2;
	float3 View: TEXCOORD3;
	float PercentHeight : COLOR0;
};

VsCloudsOutput 
RenderCloudVertex(float thicknessModifier, float3 iPosition, float3 iNormal, float2 iTexCoord)
{
	VsCloudsOutput o;  
	
	//Final Position
	o.Position = mul(float4(iPosition * thicknessModifier, 1.0f), g_WorldViewProjection);
	
	//Texture Coordinates
    o.TexCoord0 = iTexCoord; 
	
    //Calculate  Normal       
    o.Normal = normalize(mul(iNormal, (float3x3)g_World));
    
    //Position
    float3 positionInWorldSpace = mul(float4(iPosition, 1.f), g_World).xyz;
      
    //Calculate Light
	o.Light = normalize(g_Light0_Position - positionInWorldSpace);
	
	//Calculate ViewVector
	o.View = normalize(-positionInWorldSpace);
	
	o.PercentHeight = abs(iPosition.y)/g_Radius;          
    return o;
}

VsCloudsOutput 
RenderCloudsVS(
	float3 iPosition:POSITION, 
	float3 iNormal:NORMAL,
	float2 iTexCoord:TEXCOORD1)		
{
	return RenderCloudVertex(1.00, iPosition, iNormal, iTexCoord);
}

void RenderCloudsPS(VsCloudsOutput i, out float4 oColor0:COLOR0) 
{ 
	float noiseScale = 10.f;
	
	float rotatationTime = g_Time / 800;
	float indexTime = g_Time/70;
	
	float3 index = float3(i.TexCoord0, indexTime);
	float domainPhaseShift = tex3D(NoiseSampler, noiseScale * index).x;
	
	float4 cloudColor = tex2D(CloudLayerSampler, float2(i.TexCoord0.x + rotatationTime, i.TexCoord0.y));
	cloudColor *= domainPhaseShift;
	cloudColor *= g_CloudColor;
	
	//Light and Normal - renormalized because linear interpolation screws it up
	float3 light = normalize(i.Light);
	float3 normal = normalize(i.Normal);
	float3 view = normalize(i.View);
	
	float dotLightNormal = max(dot(light , normal), 0.f);	
	
	//Atmosphere Scattering
    float ratio = 1.f - max(dot(normal, view), 0.f);
	float4 atmosphere = g_GlowColor * pow(ratio, 2.f);
		
	oColor0 = (cloudColor + atmosphere) * dotLightNormal;
		
	oColor0.a = lerp(1.f, 0.f, (i.PercentHeight - .8f) / .2f);
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader = compile vs_1_1 RenderSceneVSSimple();
        PixelShader = NULL;
		Texture[0] = <g_TextureDiffuse0>;
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
    }
    
    pass PassCloudLayer
    {
		VertexShader = compile vs_1_1 RenderCloudsVS();
		PixelShader = compile ps_2_0 RenderCloudsPS();
		
		AlphaBlendEnable = TRUE;
		SrcBlend = srcalpha;
		DestBlend = ONE;		
    }
}