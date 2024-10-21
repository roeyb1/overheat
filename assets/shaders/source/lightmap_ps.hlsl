#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
    float4 color: COLOR;
    float intensity: INTENSITY;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct PassConstants {
    float4x4 view_projection_matrix;
    float3 camera_position;
};

struct DrawConstants {
    uint point_light_texture;
};

ConstantBuffer<PassConstants> g_pass_consts : REGISTER_CBV(0, 0, 0);

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 1);

SamplerState g_aniso_repeat_sampler : REGISTER_SAMPLER(0, 0, 2);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    const uint light_texture_index = uint(g_draw_consts.point_light_texture);

    const float4 light_sample = g_textures[light_texture_index].SampleLevel(g_aniso_repeat_sampler, input.tex_coord, 0);
    output.color = input.color * input.intensity * light_sample;
    if (light_sample.r > 0.1) {
        output.color.a = 1.;
    } else {
        output.color.a = 0.;
    }

    return output;
}