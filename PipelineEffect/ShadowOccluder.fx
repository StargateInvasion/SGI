float4x4 g_World : World;
float4x4 g_WorldViewProjection : WorldViewProjection;

struct VSOutput
{		
	float4 Position : POSITION;	
	float2 Depth : TEXCOORD0;
};

struct PSOutput
{	
	float4 Depth : COLOR0;
};

VSOutput VSShadow(float3 position : POSITION)
{
	VSOutput output;

	float4 positionInScreenSpace = mul(float4(position, 1.f), g_WorldViewProjection);
	output.Position = positionInScreenSpace;
	
	output.Depth.xy = positionInScreenSpace.zw;
	
	return output;
}

PSOutput PSShadow(VSOutput vsInput)
{
	PSOutput output;
	
	output.Depth = vsInput.Depth.x / vsInput.Depth.y;

	return output;
}

technique RenderShadow
{
    pass p0
    {
        VertexShader = compile vs_2_0 VSShadow();
        PixelShader = compile ps_2_0 PSShadow();

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		AlphaBlendEnable = FALSE;														
		AlphaTestEnable = FALSE;
		CullMode = CW;
    }
}