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
    float u_over_res;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 1);

SamplerState g_point_clamp_sampler : REGISTER_SAMPLER(0, 0, 2);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    float4 nearest_seed = float4(-1., -1, -1, -1);
    float nearest_dist = 99999.9;

    float resolution = 0;

    for (float y = -1.; y <= 1.; y += 1.0) {
        for (float x = -1.; x <= 1.; x += 1.) {
            float2 sample_uv = input.tex_coord + float2(x, y) * g_draw_consts.u_over_res;
            
            if (sample_uv.x < 0. || sample_uv.x > 1. || sample_uv.y < 0. || sample_uv.y > 1.) {
                continue;
            }

            float4 sample_value = g_textures[g_draw_consts.in_texture].SampleLevel(g_point_clamp_sampler, sample_uv, 0);
            float2 sample_seed = sample_value.xy;

            if (sample_seed.x != 0. || sample_seed.y != 0.) {
                float2 diff = sample_seed - input.tex_coord;
                float dist = dot(diff, diff);
                if (dist < nearest_dist) {
                    nearest_dist = dist;
                    nearest_seed = sample_value;
                }
            }
        }
    }

    output.color = nearest_seed;

    return output;
}
