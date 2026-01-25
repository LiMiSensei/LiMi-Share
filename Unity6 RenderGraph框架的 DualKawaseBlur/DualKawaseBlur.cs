//关注我的Bilibili-->  https://space.bilibili.com/416867452?spm_id_from=333.788.0.0
//2026.1.25 LiMi
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class DualKawaseBlur : ScriptableRendererFeature
{
    DualKawaseBlurPass blurPass;
    public Settings settings = new Settings();
    
    [System.Serializable]
    public class Settings
    {
        public Shader shader;                                                                       //Shader
        public string globalTextureName = "_DualKawaseBlurTexture";
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingSkybox;             //渲染时机
        [Range(1f, 10f)] public float blurRadius = 1.5f;                                           //强度
        [Range(1, 6)]public int blurPasses = 4;                                                    //升/降采样Pass次数
    }
    //----------------------------------------------------------//
    public override void Create()
    {
        settings.shader ??= Shader.Find("CustomEffects/DualKawaseBlur");
        blurPass = new DualKawaseBlurPass(settings);
        blurPass.renderPassEvent = settings.renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(settings.shader != null)renderer.EnqueuePass(blurPass);
    }
    protected override void Dispose(bool disposing)
    {
        blurPass?.Dispose();
    }
    class DualKawaseBlurPass : ScriptableRenderPass
    {
        private const string passName = "DualKawase Blur";
        private Settings _settings;
        private Material _material;
        private TextureHandle[] _downSample;
        private TextureHandle[] _upSample;
        
        public DualKawaseBlurPass(Settings settings)//初始化
        {
            _settings = settings;
            _material = CoreUtils.CreateEngineMaterial(_settings.shader);
        }
        class PassData
        {
            internal Material material;
            internal int iteration;
            internal TextureHandle source;
            internal TextureHandle renderTexture;
            internal TextureHandle[] downSample;
            internal TextureHandle[] upSample;
        }
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            //安全检查
            
            //设置材质球
            _material.SetFloat("_Offset", _settings.blurRadius);
            
            //获取数据
            var resourceData = frameData.Get<UniversalResourceData>();
            var source = resourceData.activeColorTexture;
            var textureDesc = renderGraph.GetTextureDesc(source);
            textureDesc.name = _settings.globalTextureName;
            textureDesc.clearBuffer = false;
            textureDesc.width /= 2;
            textureDesc.height /= 2;
            
            //创建纹理句柄
            _downSample = new TextureHandle[_settings.blurPasses];
            _upSample   = new TextureHandle[_settings.blurPasses];
            
            //填充纹理句柄
            var renderTexture = renderGraph.CreateTexture(textureDesc);
            for(int i = 0; i < _settings.blurPasses; i++)
            {
                //指引纹理句柄
                textureDesc.name = $"上采样{i}";
                _downSample[i]   = renderGraph.CreateTexture(textureDesc);
                textureDesc.name = $"下采样{i}";
                _upSample[i]     = renderGraph.CreateTexture(textureDesc);
                //设置纹理大小
                textureDesc.width  = Mathf.Max(textureDesc.width  / 2, 1);
                textureDesc.height = Mathf.Max(textureDesc.height / 2, 1);
            }
           
            using (var builder = renderGraph.AddUnsafePass<PassData>(passName, out var passData))
            {
                //填充数据
                passData.source        = source;
                passData.iteration     = _settings.blurPasses;
                passData.material      = _material;
                passData.downSample    = _downSample;
                passData.upSample      = _upSample;
                passData.renderTexture = renderTexture;
                //设置权限
                builder.UseTexture(source,AccessFlags.Read);
                for(int i = 0; i < _settings.blurPasses; i++)
                {
                    builder.UseTexture(_downSample[i],AccessFlags.ReadWrite);
                    builder.UseTexture(_upSample[i],AccessFlags.ReadWrite);
                }
                builder.UseTexture(renderTexture,AccessFlags.Write);
                if(renderTexture.IsValid())builder.SetGlobalTextureAfterPass(renderTexture,Shader.PropertyToID(_settings.globalTextureName));
                builder.AllowPassCulling(false);
                
                //执行函数
                builder.SetRenderFunc(static (PassData passData, UnsafeGraphContext context) => 
                {
                    var cmd = CommandBufferHelpers.GetNativeCommandBuffer(context.cmd);
                    
                    Blitter.BlitCameraTexture(cmd,  passData.source,passData.downSample[0],passData.material, 1);//将屏幕图像输出给下采样第一张
                    for (int i = 0; i < passData.iteration-1; i++)
                    {
                        //0-3       0-1 1-2 2-3  i = 0  i = 2
                        Blitter.BlitCameraTexture(cmd,passData.downSample[i],passData.downSample[i+1],passData.material, 0);
                    }
                    passData.upSample[passData.iteration-1] = passData.downSample[passData.iteration-1];//直接等于
                    for (int i = passData.iteration-1; i > 0; i--)
                    {
                        //3-0       3-2 2-1 1-0  i = 3   i = 1
                        Blitter.BlitCameraTexture(cmd,passData.upSample[i],passData.upSample[i-1],passData.material, 1);
                    }
                    Blitter.BlitCameraTexture(cmd,passData.upSample[0],passData.renderTexture,passData.material, 1);//将最后上采样输给rengderTexture
                });
                
                
            }

        }

        public void Dispose()
        {
            CoreUtils.Destroy(_material);
        }
    }
}
