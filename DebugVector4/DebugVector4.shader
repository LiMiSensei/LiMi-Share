Shader "Unlit/DebugVector"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Vector4("数值",Vector) = (9999.9911,-1234.5678,10000,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            void DebugVector4_float(sampler2D Tex,float2 UV,float4 value,out float4 Out)
            {
                 // 预计算重复使用的常量
                const float blinkFactor = round(frac(_Time.y)); // 闪烁因子只计算一次
                const float maskPos = UV.x * 10.0; // 只计算一次遮罩位置
                // 预计算所有分量的UV偏移
                const float4 yOffsets = float4(-0.3, -0.1, 0.1, 0.3);
                float2 compUV[4];
                compUV[0] = UV + float2(0, yOffsets.x);
                compUV[1] = UV + float2(0, yOffsets.y);
                compUV[2] = UV + float2(0, yOffsets.z);
                compUV[3] = UV + float2(0, yOffsets.w);
                // 预计算遮罩数组（所有分量共享）
                float digitMasks[10];
                digitMasks[0] = step(maskPos, 1.0) - step(maskPos, 0.0);
                digitMasks[1] = step(maskPos, 2.0) - step(maskPos, 1.0);
                digitMasks[2] = step(maskPos, 3.0) - step(maskPos, 2.0);
                digitMasks[3] = step(maskPos, 4.0) - step(maskPos, 3.0);
                digitMasks[4] = step(maskPos, 5.0) - step(maskPos, 4.0);
                digitMasks[5] = step(maskPos, 6.0) - step(maskPos, 5.0);
                digitMasks[6] = step(maskPos, 7.0) - step(maskPos, 6.0);
                digitMasks[7] = step(maskPos, 8.0) - step(maskPos, 7.0);
                digitMasks[8] = step(maskPos, 9.0) - step(maskPos, 8.0);
                digitMasks[9] = step(maskPos, 10.0) - step(maskPos, 9.0);
                // 预计算小数部分乘数
                const float4 fractionalMultipliers = float4(10.0, 100.0, 1000.0, 10000.0);
                // 分量结果存储
                float4 OutValues = float4(0, 0, 0, 0);
                // 并行处理四个分量
                for (int comp = 0; comp < 4; comp++)
                {
                    float compValue = value[comp];
                    // 符号处理
                    float signDigit = (compValue >= 0.0) ? 10.0 : 11.0;
                    float absoluteValue = abs(compValue);
                    // 整数部分处理
                    float integerPart = trunc(absoluteValue);
                    float integerDigitCount = (integerPart < 1.0) ? 1.0 : floor(log10(absoluteValue)) + 1.0;
                    // 小数部分处理
                    float fractionalPart = frac(absoluteValue) + 0.000001;
                    // 整数位数字提取
                    float thousandsDigit = round(trunc(integerPart * 0.001) % 10.0);
                    float hundredsDigit = round(trunc(integerPart * 0.01) % 10.0);
                    float tensDigit = round(trunc(integerPart * 0.1) % 10.0);
                    float unitsDigit = round(trunc(integerPart) % 10.0);
                    // 小数位数字提取（向量化计算）
                    float4 fracDigits = round(trunc(fractionalPart * fractionalMultipliers) % 10.0);
                    // 组合数字值
                    float digitValues[10] = {
                        signDigit,
                        thousandsDigit,
                        hundredsDigit,
                        tensDigit,
                        unitsDigit,
                        12.0,  // 小数点
                        fracDigits.x,  // 十分位
                        fracDigits.y,  // 百分位
                        fracDigits.z,  // 千分位
                        fracDigits.w   // 万分位
                    };
                    
                    // 组合数字遮罩
                    float combinedDigit = 0.0;
                    [unroll]
                    for (int j = 0; j < 10; j++) {
                        combinedDigit += digitMasks[j] * digitValues[j];
                    }
                    // 纹理采样
                    float textureOffset = combinedDigit / 13.0;
                    float2 finalUV = compUV[comp] * float2(10.0, 1.0) + float2(0.0, 0.47 - textureOffset);
                    float sampledColor = tex2D(Tex, finalUV).x;
                    // 垂直遮罩
                    float yMask = step(compUV[comp].y, 0.52) - step(compUV[comp].y, 0.45);
                    float maskedColor = sampledColor * yMask;
                    // 闪烁效果
                    float blinkColor = lerp(0.0, maskedColor, blinkFactor);
                    OutValues[comp] = (integerDigitCount >= 5.0) ? blinkColor : maskedColor;
                }
                // 组合最终输出
                Out = float4(OutValues.xyz, 1.0) + float4(OutValues.www, 0.0);
            
            }

            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };


            
            float4 _Vector4;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
               
                float4 col;
                
                DebugVector4_float(_MainTex,i.uv,_Vector4,col);
                return  col;
            }
            ENDCG
        }
    }
}
