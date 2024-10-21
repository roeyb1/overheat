#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct DrawConstants {
    uint in_texture;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 0);

SamplerState g_point_clamp_sampler : REGISTER_SAMPLER(0, 0, 1);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    float4 in_sample = g_textures[g_draw_consts.in_texture].SampleLevel(g_point_clamp_sampler, input.tex_coord, 0);
    
    output.color = float4(input.tex_coord * in_sample.a, 0., 1.);

    return output;
}
