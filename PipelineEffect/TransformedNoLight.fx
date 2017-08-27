texture			g_TextureDiffuse0		: Diffuse;


sampler TextureDiffuse0Sampler = 
sampler_state
{
    Texture		= < g_TextureDiffuse0 >;    
    MipFilter	= POINT;
    MinFilter	= LINEAR;
    MagFilter	= LINEAR;
};




void
RenderScenePS( 
	float2 iTexCoord0		: TEXCOORD0,
	out float4 oColor		: COLOR0 ) 
{ 
	oColor = tex2D( TextureDiffuse0Sampler, iTexCoord0 );
}


technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader		= NULL;
        PixelShader			= compile ps_2_0 RenderScenePS();
        
        ZEnable				= FALSE;
        
		AlphaBlendEnable	= TRUE;
		SrcBlend			= SRCALPHA;
		DestBlend			= INVSRCALPHA;          
    }
}
