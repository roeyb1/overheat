#version 450 core
#extension GL_EXT_nonuniform_qualifier: require

/** VS OUTPUTS */
layout(location = 0) in vec2 texCoord;
layout(location = 1) flat in int sprite_index;

/** FS OUTPUTS */
layout(location = 0) out vec4 FragColor;

/** BINDINGS **/
layout(set = 0, binding = 1) uniform texture2D textures[];
layout(set = 0, binding = 2) uniform sampler samplers[];

//layout(push_constant) uniform PushConsts {
//    int sprite_extent;
//    int sprite_index;
//} push_consts;

void main()
{
    int sprite_extent = 32;
    ivec2 texture_size = textureSize(sampler2D(textures[0], samplers[0]), 0);
    ivec2 num_sprites = texture_size / sprite_extent;

    vec2 tile_size_uvs = float(sprite_extent) / vec2(texture_size);

    int x = sprite_index % num_sprites.x;
    int y = texture_size.y / sprite_extent - 1 - int((sprite_index * sprite_extent) / texture_size.x);

    vec2 uv_start = tile_size_uvs * vec2(x, y);

    vec2 uvs = uv_start + texCoord * tile_size_uvs;

    FragColor = texture(sampler2D(textures[0], samplers[0]), uvs);
} 