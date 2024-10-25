#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct DrawConstants {
    uint scene_color;
    uint lighting;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 0);

SamplerState g_point_clamp_sampler : REGISTER_SAMPLER(0, 0, 1);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    float4 scene_color = g_textures[g_draw_consts.scene_color].SampleLevel(g_point_clamp_sampler, input.tex_coord, 0);
    float4 lighting = g_textures[g_draw_consts.lighting].SampleLevel(g_point_clamp_sampler, input.tex_coord, 0);
    
    output.color = scene_color * lighting;

    return output;
}
