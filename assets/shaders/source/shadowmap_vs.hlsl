#include "bindless.hlsli"

struct VSInput {
    float2 vertex_pos: VERTEX_POSITION;
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

    float2 vertex_pos = input.vertex_pos;
    float3 worlspace_pos = float3(vertex_pos, 1.) - g_pass_consts.camera_position;

    output.position = mul(g_pass_consts.view_projection_matrix, float4(worlspace_pos.xy, 0, 1.));

    return output;
}
