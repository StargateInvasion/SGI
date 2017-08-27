shared float4x4 g_ViewProjection		: ViewProjection;

technique RenderWithoutPixelShader
{
	pass Pass0
	{
		CullMode					= CCW;       
		FillMode					= SOLID;
	
        ColorVertex					= FALSE;

        NormalizeNormals			= FALSE;

		ColorWriteEnable			= RED|GREEN|BLUE|ALPHA;
	
		AlphaTestEnable				= TRUE;
		AlphaFunc					= GREATEREQUAL;
		AlphaRef					= 0x08;
	    
		AlphaBlendEnable			= TRUE;
		SrcBlend					= SRCALPHA;
		DestBlend					= INVSRCALPHA;    
    
        ColorOp[ 0 ]				= MODULATE;
        AlphaOp[ 0 ]				= MODULATE;
        ColorArg1[ 0 ]				= TEXTURE;
        ColorArg2[ 0 ]				= DIFFUSE;
        AlphaArg1[ 0 ]				= TEXTURE;
        AlphaArg2[ 0 ]				= DIFFUSE;
        TexCoordIndex[ 0 ]			= 0;
        TextureTransformFlags[ 0 ]	= DISABLE;
                
        ColorOp[ 1 ]				= DISABLE;
        AlphaOp[ 1 ]				= DISABLE;
        
        MinFilter[ 0 ]				= LINEAR;
        MagFilter[ 0 ]				= LINEAR;
        MipFilter[ 0 ]				= LINEAR;        

        Lighting					= TRUE;
        SpecularEnable				= TRUE;
        ColorVertex					= FALSE;

        AmbientMaterialSource		= MATERIAL;
        DiffuseMaterialSource		= MATERIAL;
        EmissiveMaterialSource		= MATERIAL;
        SpecularMaterialSource		= MATERIAL;
        
        MaterialAmbient				= { 1.0f, 1.0f, 1.0f, 1.0f };
        MaterialDiffuse				= { 1.0f, 1.0f, 1.0f, 1.0f };
        MaterialSpecular			= { 1.0f, 1.0f, 1.0f, 1.0f };
        MaterialEmissive			= { 1.0f, 1.0f, 1.0f, 1.0f };
        MaterialPower				= 1.0f;
        
        LightEnable[ 0 ]			= FALSE;
        LightEnable[ 1 ]			= FALSE;
        
        Ambient						= { 1.0f, 1.0f, 1.0f, 1.0f };
        
        ZEnable						= TRUE;
        ZWriteEnable				= TRUE;
        
		VertexShader				= NULL;
		PixelShader					= NULL;
	}
}

