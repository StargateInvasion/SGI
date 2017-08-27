texture		g_TextureDiffuse0		: Diffuse;


technique RenderWithoutPixelShader
{
    pass Pass0
    {   	    
		VertexShader			= NULL;
		PixelShader				= NULL;
    
        Lighting				= FALSE;
        SpecularEnable			= FALSE;
        ColorVertex				= TRUE;
        DiffuseMaterialSource	= COLOR1;

        ZEnable					= FALSE;
        ZWriteEnable			= FALSE;
        
        MinFilter[ 0 ]			= POINT;
        MagFilter[ 0 ]			= POINT;
        MipFilter[ 0 ]			= NONE;
        
		Texture[ 0 ]			= < g_TextureDiffuse0 >;
		
		AlphaTestEnable			= false;
		AlphaBlendEnable		= TRUE;
		SrcBlend				= SRCALPHA;
		DestBlend				= ONE;
    }
}


