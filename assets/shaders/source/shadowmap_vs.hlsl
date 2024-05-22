#include "bindless.hlsli"

struct VSInput {
    float4 vertex_pos: VERTEX_POSITION;
};

struct VSOutput {
    float4 position: SV_Position;
};

struct PassConstants {
    float4x4 view_projection_matrix;
    float3 camera_position;
};

ConstantBuffer<PassConstants> g_pass_consts : REGISTER_CBV(0, 0, 0);

VSOutput main(VSInput input) {
    VSOutput output = (VSOutput)0;

    float4 vertex_pos = input.vertex_pos;
    float4 worldspace_pos = vertex_pos - float4(g_pass_consts.camera_position.xy, 0., 0.);

    output.position = mul(g_pass_consts.view_projection_matrix, worldspace_pos);

    return output;
}
