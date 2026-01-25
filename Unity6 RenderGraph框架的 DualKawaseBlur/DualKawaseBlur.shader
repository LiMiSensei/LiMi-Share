//关注我的Bilibili-->  https://space.bilibili.com/416867452?spm_id_from=333.788.0.0
//2026.1.25 LiMi
Shader "CustomEffects/DualKawaseBlur"
{
    HLSLINCLUDE
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    
    float _Offset;
    //传递数据
    struct Varyings2
    {
        float4 positionCS : SV_POSITION;
        float2 uv    : TEXCOORD0;
        float4 douv01:TEXCOORD1;
        float4 douv23:TEXCOORD2;
        
        float4 upuv01:TEXCOORD3;
        float4 upuv23:TEXCOORD4;
        float4 upuv45:TEXCOORD5;
        float4 upuv67:TEXCOORD6;
        UNITY_VERTEX_OUTPUT_STEREO
    };
    //顶点
    Varyings2 DualKawaseBlurVert (Attributes input)
    {
        Varyings2 output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS =  GetFullScreenTriangleVertexPosition(input.vertexID);;
        output.uv = DYNAMIC_SCALING_APPLY_SCALEBIAS(GetFullScreenTriangleTexCoord(input.vertexID));
        
        #if UNITY_UV_STARTS_TOP
        o.uv.y = 1.0f - o.uv.y;
        #endif          
        _BlitTexture_TexelSize *= 0.5f;
        float2 offset = float2(1.0f + _Offset, 1.0f + _Offset);
        output.douv01.xy = output.uv - _BlitTexture_TexelSize * offset;
        output.douv01.zw = output.uv + _BlitTexture_TexelSize * offset;
        output.douv23.xy = output.uv - float2(_BlitTexture_TexelSize.x, -_BlitTexture_TexelSize.y) * offset;
        output.douv23.zw = output.uv + float2(_BlitTexture_TexelSize.x, -_BlitTexture_TexelSize.y) * offset;

        output.upuv01.xy = output.uv + float2(-_BlitTexture_TexelSize.x * 2.0f, 0.0f) * offset;
        output.upuv01.zw = output.uv + float2(-_BlitTexture_TexelSize.x, _BlitTexture_TexelSize.y) * offset;
        output.upuv23.xy = output.uv + float2(0.0f, _BlitTexture_TexelSize.y * 2.0f) * offset;
        output.upuv23.zw = output.uv + _BlitTexture_TexelSize * offset;
        output.upuv45.xy = output.uv + float2(_BlitTexture_TexelSize.x * 2.0f, 0.0f) * offset;
        output.upuv45.zw = output.uv + float2(_BlitTexture_TexelSize.x, -_BlitTexture_TexelSize.y) * offset;
        output.upuv67.xy = output.uv + float2(0.0f, -_BlitTexture_TexelSize.y * 2.0f) * offset;
        output.upuv67.zw = output.uv - _BlitTexture_TexelSize * offset;
        return output;
    }
    //下采样
    half4 DownSamplefrag (Varyings2 i) : SV_Target
    {
        half4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.uv) * 4;
        col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.douv01.xy);
        col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.douv01.zw);
        col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.douv23.xy);
        col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.douv23.zw);
        return col * 0.125f;
    }
    //上采样
    half4 UpSampleFrag (Varyings2 i) : SV_Target
    {
       half4 col = 0.0f;
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv01.xy);
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv01.zw) * 2.0f;
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv23.xy);
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv23.zw) * 2.0f;
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv45.xy);
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv45.zw) * 2.0f;
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv67.xy);
       col += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.upuv67.zw) * 2.0f;
       return col * 0.0833f;
    }
    ENDHLSL

    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        ZWrite Off Cull Off
        
        Pass
        {
            Name "DownSample"

            HLSLPROGRAM
            #pragma vertex DualKawaseBlurVert
            #pragma fragment DownSamplefrag
            ENDHLSL
        }
        Pass
        {
            Name "UpSample"

            HLSLPROGRAM
            #pragma vertex DualKawaseBlurVert
            #pragma fragment UpSampleFrag
            ENDHLSL
        }
    }
}
