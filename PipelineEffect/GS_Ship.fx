#define PBR 				// Switches to Vanilla shader model - note that it will shade strange with non PBR textures.

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
	//return color;

	//When external colors and the data texture are redone this can be reenabled.
	return float4(color.rgb * (color.rgb * (color.rgb * 0.305306011f + 0.682171111f) + 0.012522878f), color.a);
}
float3 SRGBToLinear(float3 color)
{
	//return color;

	//When external colors and the data texture are redone this can be reenabled.
	return float3(color * (color * (color * 0.305306011f + 0.682171111f) + 0.012522878f));
}

float4 LinearToSRGB(float4 color)
{
	//return color;

	//When external colors and the data texture are redone this can be reenabled.
	float3 S1 = sqrt(color.rgb);
	float3 S2 = sqrt(S1);
	float3 S3 = sqrt(S2);
	return float4(0.662002687 * S1 + 0.684122060 * S2 - 0.323583601 * S3 - 0.225411470 * color.rgb, color.a);
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
/////////////////////////////////////////////////PBR////////////////////////////////
	// If we want to do image based PBR lighting, we need to work in world space
	// Note we will skip tangent binormals and instead do per pixel cotangent derivative mapping, which allows the modders a lot more freedom in uv mapping
	struct VsOutputWS
	{
		float4 Position					: POSITION;
		float2 TexCoord					: TEXCOORD0;
		float3 PosWS					: TEXCOORD1;
		float3 NormalWS					: TEXCOORD2;
	};
	
	VsOutputWS RenderSceneWSVS( 
		float3 position : POSITION, 
		float3 normal : NORMAL,
		float3 tangent : TANGENT,
		float2 texCoord : TEXCOORD0)
	{
		VsOutputWS output;
		
		output.Position = mul(float4(position, 1.0f), g_WorldViewProjection);
		output.TexCoord = texCoord;	
		output.PosWS	= mul(float4(position, 1.f), g_World).xyz;
		output.NormalWS = normalize(mul(normal, (float3x3)g_World));
		
		return output;
	}

	float Square(float X)
	{
		return X * X;
	}
	
	float Pow4(float X)
	{
		return Square(X) * Square(X);
	}
	
	float Pow5(float X)
	{
		return Pow4(X) * X;
	}	
	
	float3 Square(float3 X)
	{
		return X * X;
	}
	
	float ToLinear(float aGamma)
	{
		return pow(aGamma, 2.2);
	}
		
	struct PBRProperties
	{
		float3 SpecularColor;
		float3 DiffuseColor;
		float4 EmissiveColor;
		float Roughness;
		float RoughnessMip;
		float AO;
		float SubsurfaceOpacity;
	};

	PBRProperties UnpackProperties(float4 colorSample, float4 dataSample, float4 normalSample)
	{
		PBRProperties Output;
		Output.SpecularColor 		= max((float3)0.04, dataSample.r * colorSample.rgb);
		Output.DiffuseColor 		= saturate(colorSample.rgb  - Output.SpecularColor);
		Output.EmissiveColor 		= float4(Square(colorSample.rgb) * 8.0, colorSample.a) * ToLinear(dataSample.g);
		Output.Roughness 			= max(0.02, dataSample.w);
		Output.RoughnessMip 		= dataSample.w * 8.0;
		Output.AO 					= normalSample.b;
		Output.SubsurfaceOpacity	= normalSample.r;
		return Output;
	}
	
	// Frostbite presentation (moving frostbite to pbr)
	float3 GetSpecularDominantDir(float3 vN, float3 vR, PBRProperties Properties)
	{
		float InvRoughness = 1.0 - Properties.Roughness;
		float lerpFactor = saturate(InvRoughness * (sqrt(InvRoughness) + Properties.Roughness));
	
		return lerp(vN, vR, lerpFactor);
	}

	// Brian Karis(Epic's) optimized unified term derived from Call of Duty metallic/dielectric term
	float3 AmbientBRDF(float NoV, PBRProperties Properties)
	{
		float4 r = Properties.Roughness * float4(-1.0, -0.0275, -0.572, 0.022) + float4(1.0, 0.0425, 1.04, -0.04);
		float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
		float2 AB = float2(-1.04, 1.04) * a004 + r.zw;
	
		AB.y *= (1.0 - 1.0 / (1.0 + max(0.0, 50.0 * Properties.SpecularColor.g))) * 3.0;
	
		return Properties.SpecularColor * AB.x + AB.y;
	}
	
	// Frostbite presentation (moving frostbite to pbr)
	float3 GetDiffuseDominantDir(float3 N, float3 V, float NoV, PBRProperties Properties)
	{
		float a = 1.02341 * Properties.Roughness - 1.51174;
		float b = -0.511705 * Properties.Roughness + 0.755868;
		// The result is not normalized as we fetch in a cubemap
		return lerp(N , V , saturate((NoV * a + b) * Properties.Roughness));
	}
	
	struct PBRDots
	{
		float NoV;
		float NoL;
		float VoL;
		float NoH;
		float VoH;
	};
	
	PBRDots GetDots(float3 N, float3 V, float3 L)
	{	
		PBRDots Ouput;
		Ouput.NoL = dot(N, L);
		Ouput.NoV = dot(N, V);
		Ouput.VoL = dot(V, L);
		float invLenH = rcp(sqrt( 2.0 + 2.0 * Ouput.VoL));
		Ouput.NoH = saturate((Ouput.NoL + Ouput.NoV) * invLenH);
		Ouput.VoH = saturate(invLenH + invLenH * Ouput.VoL);
		Ouput.NoL = saturate(Ouput.NoL);
		Ouput.NoV = saturate(abs(Ouput.NoV * 0.9999 + 0.0001));
		return Ouput;
	}
	
	// Diffuse term
	float3 DiffuseBurley(PBRProperties Properties, PBRDots Dots)
	{
		float FD90 = 0.5 + 2.0 * Square(Dots.VoH) * Properties.Roughness;
		float FdV = 1.0 + (FD90 - 1.0) * Pow5( 1.0 - Dots.NoV );
		float FdL = 1.0 + (FD90 - 1.0) * Pow5( 1.0 - Dots.NoL );
		return Properties.DiffuseColor * 0.3183098862 * FdV * FdL; // 0.31831 = 1/pi
	}

	// Specular lobe
	float D_GGX(PBRProperties Properties, PBRDots Dots)
	{
		float a2 = Pow4(Properties.Roughness);	
		float d = Square((Dots.NoH * a2 - Dots.NoH) * Dots.NoH + 1.0);
		return a2 / (3.1415926531 * d);				
	}

	// Geometric attenuation
	float V_GGX(PBRProperties Properties, PBRDots Dots)
	{
		float a = Square(Properties.Roughness);
		float Vis_SmithV = Dots.NoL * (Dots.NoV * (1.0 - a) + a);
		float Vis_SmithL = Dots.NoV * (Dots.NoL * (1.0 - a) + a);
		return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
	}
	
	// Fresnel term
	float3 F_GGX(PBRProperties Properties, PBRDots Dots)
	{
		float Fc = Pow5(1.0 - Dots.VoH);

		return saturate(50.0 * Properties.SpecularColor.g) * Fc + (1.0 - Fc) * Properties.SpecularColor;
	}
	
	// All in one, Epics implementation, originally from Disney/Pixar Principled shader
	// NOTE!! To mitigate a floating point overflow, on specular peaks we saturate the result
	// we should bloom it, but we can't.
	float3 SpecularGGX(PBRProperties Properties, PBRDots Dots)
	{
		return saturate(F_GGX(Properties, Dots) * (D_GGX(Properties, Dots) * V_GGX(Properties, Dots)));
	}

	// Morten Mikkelsen cotangent derivative normal mapping, more accurate than using mesh tangents/normals, handles mirroring and radial symmetry perfectly.
	float3 CotangentDerivativeMap(float3 Pos, float3 Normal, float3 NMap, float2 UV)
	{
		float3 DPX 			= ddx(Pos);
		float3 DPY 			= ddy(Pos);
		float2 DUVX 		= ddx(UV);
		float2 DUVY 		= ddy(UV);
		float3 DPXPerp 		= cross(Normal, DPX);		
		float3 DPYPerp 		= cross(DPY, Normal);		
		float3 Tanget 		= DPYPerp * DUVX.x + DPXPerp * DUVY.x;
		float3 Cotangent 	= DPYPerp * DUVX.y + DPXPerp * DUVY.y;
		float InvMax		= pow(max(dot(Tanget, Tanget), dot(Cotangent, Cotangent)), -0.5);
		Tanget				*= InvMax;
		Cotangent 			*= InvMax;
		return normalize(mul(NMap, float3x3(Tanget, Cotangent, Normal)));	
	}
	
	// recreate blue normal map channel
	float DeriveZ(float2 Nxy)
	{	
	
		float Z = sqrt(abs(1.0 - Square(Square(Nxy.x) - Square(Nxy.y))));
		
		return Z;
	}
		
	// recreate blue normal map channel
	float2 ToNormalSpace(float2 Nxy)
	{	
		return Nxy * 2.0 - 1.0;
	}	
	
	float3 GetNormalDXT5(float4 N)
	{
		float2 Nxy = N.wy;
		Nxy = ToNormalSpace(Nxy);
		// play safe and normalize
		return normalize(float3(Nxy, DeriveZ(Nxy)));
	}
	
	float Bias(float value, float b)
	{
		return (b > 0.0) ? pow(value, log(b) / log(0.5)) : 0.0;
		// maybe faster when used in a nested ternary operator - can't profile it proper, so shoot!
		// Second that, DX9 predictive jumping, probably handles it fine
		//return saturate(ceil(b)) * pow(value, log(b) / log(0.5));
	}
	
	// contrast function.
	float Gain(float value, float g)
	{
		return 0.5 * ((value < 0.5) ? Bias(2.0 * value, 1.0 - g) : (2.0 - Bias(2.0 - 2.0 * value, 1.0 - g)));
	}
	
	float EmpiricalSpecularAO(PBRProperties Properties)
	{
		// basically a ramp curve allowing ao on very diffuse specular
		// and gradually less so as the reflection hardens.
		float fSmooth = 1.0 - Properties.Roughness;
		float fSpecAo = Gain(Properties.AO, 0.5 + max(0.0 , fSmooth * 0.4));
		
		return saturate(fSpecAo + lerp(0.0, 0.5, Pow4(fSmooth)));
	}
	
	float CheapSpecularAO(PBRProperties Properties)
	{
		return Properties.AO * Properties.AO * (3.0 - 2.0 * Properties.AO);
	}
	
	// marmoset horizon occlusion http://marmosetco.tumblr.com/post/81245981087
	float ApproximateSpecularSelfOcclusion(float3 vR, float3 vertNormalNormalized)
	{
		const float fFadeParam = 1.1;
		return saturate(1 + fFadeParam * dot(vR, vertNormalNormalized));
	}
	//NOT worth it
	// fixes the DX9 hard cubemap edges.
	float3 GetFixedCubemapSample(samplerCUBE Cubemap, float3 Vector, float RoughnessMip)
	{
		float3 VectorWrap			= Vector * (3.0 - sqrt(abs(Vector)) * 2.0);
		float2 CubeGradients 		= saturate(abs(Vector.xz) * 8.0 - 4.5);		
		CubeGradients 				*= CubeGradients * (3.0 - 2.0 * CubeGradients);		
		float3 AmbientReflection 	= texCUBElod(Cubemap, float4(VectorWrap.x, Vector.y, Vector.z, RoughnessMip)).rgb;
		AmbientReflection 			= lerp(texCUBElod(Cubemap, float4(Vector.x, VectorWrap.y, Vector.z, RoughnessMip)).rgb, AmbientReflection, CubeGradients.x);
		AmbientReflection 			= lerp(AmbientReflection, texCUBElod(Cubemap, float4(Vector.x, Vector.y, VectorWrap.z, RoughnessMip)).rgb, CubeGradients.y);
		return AmbientReflection;
	}
	
float4 GetFinalPixelColorPBR(float2 texCoord, float3 pos, float3 normal)
{   
	// get all vector attributes and normalize them all.
	float3 view		 			= normalize(-pos);
	float3 light 				= normalize(g_Light0_Position - pos);
	float3 normalVert			= normalize(normal);

	// sample textures
	// Note we are using DXT5 for normal maps, NOT DXT5_NM, sacrificing a little bit of quality to be able to have ao in one of the high compressed channels.
	float4 normalSample			= tex2D(TextureNormalSampler, texCoord);
	float4 colorSample			= GetColorWithTeamColorSample(SRGBToLinear(tex2D(TextureColorSampler, texCoord)));
	float4 dataSample 			= tex2D(TextureDataSampler, texCoord);

	PBRProperties Properties 	= UnpackProperties(colorSample, dataSample, normalSample);
	
	normal						= GetNormalDXT5(normalSample);
	
	normal 						= CotangentDerivativeMap(pos, normalVert, normal, texCoord);
		
	float4 finalColor			= Properties.EmissiveColor;
	
	float NoV					= dot(view, normal);	
	float3 reflection			= -(view - 2.0 * normal * NoV);
	
	float SpecularAO 			= ApproximateSpecularSelfOcclusion(reflection, normal);
	SpecularAO					*= EmpiricalSpecularAO(Properties);
	
	float3 diffuse = 0.0;
	float3 specular = 0.0;
	
	float3 ReflectionSample 	= SRGBToLinear(texCUBElod(TextureEnvironmentCubeSampler, float4(reflection, Properties.RoughnessMip))).rgb;
	
	specular 					+= ReflectionSample * AmbientBRDF(saturate(abs(dot(view, normal))), Properties);

	float3 DiffuseSample		= SRGBToLinear(texCUBE(EnvironmentIlluminationCubeSampler, normal)).rgb;
		
	diffuse 					+= Properties.DiffuseColor * DiffuseSample;
	
	float3 subsurfaceScatter 	= 0.0;
	
	float shadowScalar 			= dot(normal, light);
	if(Properties.SubsurfaceOpacity > 0)
	{
		float3 subsurfaceColor 		= Square(SRGBToLinear(tex2Dbias(TextureColorSampler, float4(texCoord, 0.0, 2.0)).rgb));	
		float InScatter				= pow(saturate(dot(light, -view)), 12) * lerp(3, .1f, Properties.SubsurfaceOpacity);
		float NormalContribution	= saturate(dot(normal, normalize(view + light)) * Properties.SubsurfaceOpacity + 1.0 - Properties.SubsurfaceOpacity);
		float BackScatter		 	= Properties.AO * NormalContribution * 0.1591549431;
		subsurfaceScatter 			= lerp(BackScatter, 1, InScatter) * subsurfaceColor * saturate(shadowScalar + Properties.SubsurfaceOpacity);
		
		InScatter					= pow(NoV, 12) * lerp(3, .1f, Properties.SubsurfaceOpacity);
		NormalContribution			= saturate(dot(normal, reflection) * Properties.SubsurfaceOpacity + 1.0 - Properties.SubsurfaceOpacity);
		BackScatter		 			= Properties.AO * NormalContribution * 0.1591549431;
		subsurfaceScatter	 		+= subsurfaceColor * lerp(BackScatter, 1, InScatter) * SRGBToLinear(texCUBE(EnvironmentIlluminationCubeSampler, -normal)).rgb;
		
	}

	shadowScalar 				= saturate(shadowScalar);
	
	if(shadowScalar > 0.0)
	{
		PBRDots dots 			= GetDots(normal, view, light);
	
		specular 				+= SpecularGGX(Properties, dots) * shadowScalar;
		diffuse 				+= DiffuseBurley(Properties, dots) * shadowScalar;
		
	}
		
	finalColor.rgb 				+= (diffuse * Properties.AO * (1.0 - Properties.SubsurfaceOpacity) + specular * SpecularAO) + subsurfaceScatter;

	return LinearToSRGB(finalColor);
}

float4 RenderScenePBRPS(VsOutputWS input) : COLOR0
{ 
	return GetFinalPixelColorPBR(input.TexCoord, input.PosWS, input.NormalWS);
}

technique RenderWithPixelShader
{
    pass Pass0
    {
	#ifdef PBR
		VertexShader = compile vs_3_0 RenderSceneWSVS();
		PixelShader = compile ps_3_0 RenderScenePBRPS();
	#else	
        VertexShader = compile vs_2_0 RenderSceneVS();
        PixelShader = compile ps_2_0 RenderScenePS();
	#endif
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
}
