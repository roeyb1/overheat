#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct DrawConstants {
    uint jf_texture;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 0);

SamplerState g_linear_clamp_sampler : REGISTER_SAMPLER(0, 0, 1);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    float2 nearest_seed = g_textures[g_draw_consts.jf_texture].SampleLevel(g_linear_clamp_sampler, input.tex_coord, 0).xy;
    float dist = clamp(distance(input.tex_coord, nearest_seed), 0.0, 1.0);

    output.color = float4(dist, dist, dist, 1.);

    return output;
}
