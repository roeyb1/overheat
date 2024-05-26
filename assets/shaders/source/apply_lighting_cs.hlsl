#include "bindless.hlsli"

struct PushConsts {
    uint2 resolution;
    float2 texel_size;
    uint input_color_image_index;
    uint input_lightmap_image_index;
    uint output_image_index;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 0);
RWTexture2D<float4> g_rw_textures[65536] : REGISTER_UAV(1, 0, 0);

PUSH_CONSTS(PushConsts, g_push_consts);

[numthreads(8, 8, 1)]
void main(uint3 thread_id: SV_DispatchThreadID) {

    float3 scene_color = g_textures[g_push_consts.input_color_image_index].Load(int3(thread_id.xy, 0)).rgb;

    float3 light_color = g_textures[g_push_consts.input_lightmap_image_index].Load(int3(thread_id.xy, 0)).rgb;

    float3 color = scene_color * light_color;

    g_rw_textures[g_push_consts.output_image_index][thread_id.xy] = float4(color, 1.f);
}
