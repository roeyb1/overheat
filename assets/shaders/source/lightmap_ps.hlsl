#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct PassConstants {
    float4x4 view_projection_matrix;
    float3 camera_position;
};

struct DrawConstants {
    float4 color;
    float2 instance_pos;
    float radius;
    float intensity;

    uint point_light_texture;
};

ConstantBuffer<PassConstants> g_pass_consts : REGISTER_CBV(0, 0, 0);

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 1);

SamplerState g_point_clamp_sampler : REGISTER_SAMPLER(0, 0, 2);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    output.color.xyz = g_draw_consts.color.xyz * g_draw_consts.intensity * g_textures[g_draw_consts.point_light_texture].SampleLevel(g_point_clamp_sampler, input.tex_coord, 0).xyz;
    // clear the alpha back to 1 so we can re-draw shadowmaps for the next light
    output.color.a = 1.;

    return output;
}
