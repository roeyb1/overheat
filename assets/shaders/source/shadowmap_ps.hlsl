#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
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

    output.color.a = 0.;

    return output;
}
