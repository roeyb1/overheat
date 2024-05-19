
#include "bindless.hlsli"

struct VSInput {
    float2 vertex_pos: VERTEX_POSITION;
    float2 tex_coord: TEXCOORD;

    float4 color: COLOR;
    float2 instance_pos: INSTANCE_POS;
    float radius: RADIUS;
    float intensity: INTENSITY;
};

struct VSOutput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
    float4 color: COLOR;
    float intensity: INTENSITY;
};

struct PassConstants {
    float4x4 view_projection_matrix;
    float3 camera_position;
};

ConstantBuffer<PassConstants> g_pass_consts : REGISTER_CBV(0, 0, 0);

VSOutput main(VSInput input) {
    VSOutput output = (VSOutput)0;

    float2 vertex_pos = input.vertex_pos;
    float3 scaled_vertex_pos = float3(vertex_pos, 1.) * float3(input.radius, input.radius, 1);
    float3 worlspace_pos = float3(input.instance_pos, 0.) - g_pass_consts.camera_position;

    output.position = mul(g_pass_consts.view_projection_matrix, float4((scaled_vertex_pos + worlspace_pos).xy, 0, 1.));
    output.tex_coord = input.tex_coord;
    output.color = input.color;
    output.intensity = input.intensity;

    return output;
}
