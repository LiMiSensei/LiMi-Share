//- Import from libraries.

import lib-sampler.glsl
import lib-vectors.glsl
import lib-env.glsl
import lib-bent-normal.glsl
import lib-pbr.glsl
//-------
//: param custom { "default": 1, "label": "MainLightColor", "widget": "color" }
uniform vec3 u_main_lightColor;
//-------
//: param auto channel_basecolor
uniform SamplerSparse basecolor_tex;
//: param auto channel_roughness
uniform SamplerSparse roughness_tex;
//: param auto channel_metallic
uniform SamplerSparse metallic_tex;

//: param auto channel_specularlevel
uniform SamplerSparse specularlevel_tex;

//--------EXTERNAL ---------------------------------------------------//
//: param auto main_light
uniform vec4 uniform_main_light;

//: param auto environment_max_lod
uniform float environment_max_lod;


float PerceptualRoughnessToMipmapLevel(float perceptualRoughness)
{
    float mip = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
	mip = pow( mip, 0.4 );
	mip *= 0.97;
	float mipmap_start = 0;
	float mipmap_end = environment_max_lod - 1.5;
	return mip * ( mipmap_end - mipmap_start ) + mipmap_start;
}
vec3 GlossyEnvironmentReflection(LocalVectors vectors, float perceptualRoughness, float occlusion)
{
    vec3 debug = vec3(0, 0, 0);
    vec3 irradiance = vec3(0.0);
    float mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
    vec3 envT =  worldToEnvSpace(vectors.tangent);
    vec3 envB =  worldToEnvSpace(vectors.bitangent);
    vec3 envN =  worldToEnvSpace(vectors.normal);
    vec3 envE =  worldToEnvSpace(vectors.eye);
    for(int i=0; i < nbSamples; ++i)
    {
      vec2 Xi = fibonacci2DDitheredTemporal(i, nbSamples);
      vec3 Hn = importanceSampleGGX(Xi, envT, envB, envN, perceptualRoughness);
      vec3 Ln = -reflect(envE,Hn);
      irradiance += envSample(Ln, mip);
    }
    irradiance /= float(nbSamples);
 
	const float threshold = 0.6;
	mip =  ( mip - 1 ) / ( environment_max_lod - 1 );
	mip = 1 - ( 1-threshold ) * mip;
	mip = max( mip, threshold );
	float irradiance_length = dot( irradiance, irradiance );
   	irradiance *= occlusion;
    return irradiance;
}




float SpecularURP(vec3 normalWS, vec3 viewDirWS, vec3 lightDirWS, float clampSmoothness)
{
    //roughness-->roughnessSq
    float roughness = 1.0 - clampSmoothness;
    roughness *= roughness;
    float roughnessSq = roughness * roughness;
    //NdotH-->
    vec3 halfDir = normalize(viewDirWS + lightDirWS);

    float nDotH = dot(normalWS, halfDir);
    float clampedNDotHSq = clamp(nDotH, 0.0, 1.0);
    clampedNDotHSq *= clampedNDotHSq;
    //LdotH-->
    float lDotH = dot(halfDir, lightDirWS);
    float clampedLDotHSq = clamp(lDotH, 0.0, 1.0);
    clampedLDotHSq *= clampedLDotHSq;
    //标记2
    float denominator = clampedNDotHSq * (roughnessSq - 1.0) + 1.00001;
    denominator *= denominator;
    //标记3
    float visibilityTerm = max(clampedLDotHSq, 0.1);
    float combinedTerm = denominator * visibilityTerm;
    //
    float roughnessFactor = roughness * 4.0 + 2.0;
    float finalDenominator = combinedTerm * roughnessFactor;
    float specularTerm = (roughnessSq / finalDenominator) - 6.103515625e-5;
    
    specularTerm = clamp(specularTerm, 0.0, 1000.0);
    return specularTerm;
}

vec3 ReflectanceURP(vec3 baseColor,vec3 normalWS, vec3 viewDirWS,float smoothness, float metallic )
{
    float fresnelEffect = pow( (1.0 - clamp( dot(normalize(normalWS), normalize(viewDirWS)) ,0,1 ) ), 4);
    float roughness2 = 1 - smoothness;roughness2 *= roughness2;
    float a1 = 1 / (roughness2 + 1);
    float b1 = 0.04 + smoothness;
    float b2 = mix(0.04,b1,fresnelEffect);
    float c1 = a1 * b2;
    vec3 Out = mix(vec3(c1),baseColor,vec3(metallic));
    return Out;
}







//----------------------------
// SHADER
void shade(V2F inputs)
{
    //基础向量
    vec3 baseColor = getBaseColor(basecolor_tex, inputs.sparse_coord);         //基础色
    float roughness = getRoughness(roughness_tex, inputs.sparse_coord);        //粗糙度（感性）
    float metallic = getMetallic(metallic_tex, inputs.sparse_coord);           //金属度
    float specularLevel = getSpecularLevel(specularlevel_tex, inputs.sparse_coord);
    vec3 specColor = generateSpecularColor(specularLevel, baseColor, metallic);
    LocalVectors vectors = computeLocalFrame(inputs);
    //computeBentNormal(vectors,inputs);
    vec3 N = normalize(vectors.normal);
    vec3 V = normalize(vectors.eye);
    vec3 L = normalize(uniform_main_light.xyz);
    float fresnel = 1 - clamp(dot(N, V), 0.0, 1.0);                            //菲涅尔
    float smoothness = 1 - roughness;                                          //平滑度（感性）
    float clampSmoothness = clamp(smoothness, 0.0, 0.94);
    float f0 = 0.04;
    float occlusion = getAO(inputs.sparse_coord, true, use_bent_normal);       //AO

    // Specular
    float specular = SpecularURP(N,V,L,clampSmoothness);
    // Reflectance
    vec3 reflectance = ReflectanceURP(baseColor,N,V,smoothness,metallic);
    //环境反射
    vec3 envColor = GlossyEnvironmentReflection(vectors,roughness,1);
    // IBL
    vec3 IBL = envIrradiance(getDiffuseBentNormal(vectors));
    vec3 EC_IBL = mix(baseColor,vec3(0),metallic) * IBL;//能量守恒
    //AO
    float EC_AO = mix(N.z,1,fresnel) * occlusion;//能量守恒
    //Diffuse Lambert
    float mainDiffuse = clamp(dot(N,L),0,1);
    //MainLightColor 
    vec3 mainSpecular = vec3(mainDiffuse) * vec3(specular) * reflectance;
    float normalization_denominator = dot(mainSpecular, vec3(0.333)) + mainDiffuse;
    vec3 tola = ((vec3(mainDiffuse) + mainSpecular) * (u_main_lightColor)) / normalization_denominator;
    vec3 outputColor = normalization_denominator <= 0 ? (u_main_lightColor) : tola;

    //最后输出
    //第一部分：（环境反射 * 反射率 + IBL）* AO
    vec3 aa1 = (envColor * reflectance + EC_IBL) * vec3(EC_AO);
    //第二部分：lerp(BaseColor * AO，0，Metallic)
    vec3 aa2 = mix(vec3(EC_AO) * baseColor,vec3(0),metallic);
    //
    vec3 aa3 = mainDiffuse * aa2 + mainSpecular * EC_AO;
    vec3 aa4 = aa3 * outputColor + aa1;
   
    //Out
    diffuseShadingOutput(vec3(aa4));
}

