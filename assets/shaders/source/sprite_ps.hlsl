#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
    uint sprite_index: SPRITE_INDEX;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct PassConstants {
    float4x4 view_projection_matrix;
    float3 camera_position;
};

struct DrawConstants {
    uint spritesheet_index;
    uint sprite_extent;
};

ConstantBuffer<PassConstants> g_pass_consts : REGISTER_CBV(0, 0, 0);

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 1);

SamplerState g_aniso_repeat_sampler : REGISTER_SAMPLER(0, 0, 2);

PUSH_CONSTS(DrawConstants, g_draw_consts);

PSOutput main(PSInput input) {
    PSOutput output;

    const uint spritesheet_index = uint(g_draw_consts.spritesheet_index);

    uint width = 0;
    uint height = 0;
    uint levels = 0;
    g_textures[spritesheet_index].GetDimensions(0, width, height, levels);

    uint2 num_sprites = uint2(width, height) / uint2(g_draw_consts.sprite_extent, g_draw_consts.sprite_extent);

    float2 tile_size_uvs = (g_draw_consts.sprite_extent, g_draw_consts.sprite_extent) / float2(width, height);

    int x = input.sprite_index % num_sprites.x;
    int y = height / g_draw_consts.sprite_extent - 1 - int(input.sprite_index * g_draw_consts.sprite_extent) / width;

    float2 uv_start = tile_size_uvs * float2(x, y);

    float2 uvs = uv_start + input.tex_coord * tile_size_uvs;

    output.color = g_textures[spritesheet_index].SampleLevel(g_aniso_repeat_sampler, uvs, 0);

    return output;
}