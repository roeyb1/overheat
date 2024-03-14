#version 450 core
#extension GL_EXT_nonuniform_qualifier: require

/** VERTEX INPUTS **/
layout (location = 0) in vec2 vertex_pos;
layout (location = 1) in vec2 uv;

// per-instance data
layout (location = 2) in vec3 pos;
layout (location = 3) in vec2 scale;
layout (location = 4) in int spriteIndex;

/** VS OUTPUTS **/
layout(location = 0) out vec2 texCoord;
// per-instance data passthrough to fragment shader
layout(location = 1) flat out int sprite_index;

/** BINDINGS **/
layout(set = 0, binding = 3) uniform SceneView {
    mat4 projection;
    vec2 view_pos;
} scene_view;

void main() {
    vec2 scaled_position = vertex_pos * scale;
    gl_Position = scene_view.projection * vec4(pos.xy + scaled_position - scene_view.view_pos, pos.z, 1.0);

    texCoord = uv;
    sprite_index = spriteIndex;
}