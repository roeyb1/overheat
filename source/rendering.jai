#scope_export

game_window: Window_Type;
g_window_width, g_window_height: s32;

main_view_camera: Camera;

Sprite :: struct {
    sheet: *SpriteSheet = null;
    scale: Vector2 = .{1, 1};
    index: s32 = 0;
    z_order: s8 = 0;

    time_till_switch: float;
    time_per_frame: float;
}

// Copy over the sprite data required for rendering so we don't need to directly reference it
Sprite_Draw_Cmd :: struct {
    sheet: *SpriteSheet;

    sprite_index: s32;
    z_order: s8;

    position: Vector2;
    scale: Vector2;
}

rendering_init :: () -> bool {
    log("Initialized rendering systems...");

    game_window = create_window(800, 600, "Overheat");
    g_window_width, g_window_height = Simp.get_render_dimensions(game_window);

    Simp.set_render_target(game_window);

    recompute_camera_projection(*main_view_camera);

    init_rendering_resources();

    log("Rendering systems initialized successfully");
    return true;
}

rendering_shutdown :: () {
    // no work required at the moment
    log("Rendering systems shutdown successfully");
}

rendering_begin_frame :: () {
    update_window_events();

    for get_window_resizes() {
        Simp.update_window(it.window);
        if it.window == game_window {
            g_window_width = it.width;
            g_window_height = it.height;

            recompute_camera_projection(*main_view_camera);
        }
    }

    for events_this_frame {
        if it.type == .QUIT then g_should_exit = true;
    }

    Simp.clear_render_target(0.1, 0.1, 0.1, 1.0);
}

rendering_end_frame :: () {
    Simp.swap_buffers(game_window);

    sprite_draw_cmds.count = 0;
}

update_current_sprite :: (using sprite: *Sprite,delta_time: float) {

    time_till_switch -= delta_time;

    if time_till_switch <= 0.0 {
        if index < sprite.sheet.count-1 {
            index = sprite.index+1;
        }
        else index = 0;
        time_till_switch = time_per_frame;
    }
}

draw_sprite :: (camera: *Camera, sprite: *Sprite, position: Vector2) {
    sprite_draw_cmd := array_add(*sprite_draw_cmds);

    sprite_draw_cmd.sheet = sprite.sheet;
    sprite_draw_cmd.scale = sprite.scale;
    sprite_draw_cmd.sprite_index = sprite.index;
    sprite_draw_cmd.z_order = sprite.z_order;

    sprite_draw_cmd.position = position;
}

#scope_file
DrawBucket :: struct {
    start: u64;
    count: u64;
    sprite_sheet: *SpriteSheet;
}
#scope_export

render_scene :: (camera: *Camera) {
    if sprite_draw_cmds.count == 0 then return;

    // we might do a bunch of allocations in here manipulating arrays, but none of them need to stick around
    push_allocator(temp);

    // sort the sprite draw commands into draw buckets so we can instance draw calls with sprites using the same sheet:
    quick_sort(sprite_draw_cmds, x => cast(s64) x.sheet);

    draw_buckets: [..] DrawBucket;
    instance_data: [..] InstanceData;

    // Build the buckets:
    current_bucket: *DrawBucket = null;
    for * draw_cmd : sprite_draw_cmds {
        // Since the draw commands are already sorted by spritesheet
        // we can assume that the moment we find a new spritesheet that doesn't match, we're starting a new bucket.
        if current_bucket == null || draw_cmd.sheet != current_bucket.sprite_sheet {
            // first time this runs, current will be null
            if current_bucket != null {
                current_bucket.count = cast(u64) it_index - current_bucket.count;
            }

            current_bucket = array_add(*draw_buckets);
            current_bucket.start = cast(u64) it_index;
            current_bucket.sprite_sheet = draw_cmd.sheet;
        }

        instance: *InstanceData = array_add(*instance_data);
        instance.position = make_vector3(draw_cmd.position, cast(float) draw_cmd.z_order / 128.);
        instance.scale = draw_cmd.scale;
        instance.sprite_index = draw_cmd.sprite_index;
    }

    current_bucket.count = cast(u64) instance_data.count - current_bucket.start;

    glBindBuffer(GL_ARRAY_BUFFER, instance_vbo);    
    glBufferData(GL_ARRAY_BUFFER, instance_data.count * size_of(InstanceData), instance_data.data, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);


    glUseProgram(sprite_shader_prog);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE0);

    // set shader parameters that won't change between draw calls:
    set_shader_mat4(sprite_shader_prog, "projection", camera.projection);
    set_shader_vec2(sprite_shader_prog, "view_pos", camera.position);

    glBindVertexArray(quad_vao);

    for * draw : draw_buckets {
        glBindTexture(GL_TEXTURE_2D, draw.sprite_sheet.texture.gl_handle);
        set_shader_sint(sprite_shader_prog, "sprite_extent", draw.sprite_sheet.extent);
        glDrawElementsInstancedBaseInstance(GL_TRIANGLES, 6, GL_UNSIGNED_INT, cast (*void) 0, cast (u32) draw.count, cast (u32) draw.start);
    }


    // Restore opengl state
    glBindVertexArray(0);

    glUseProgram(0);
}

Simp :: #import "Simp";
#import "Window_Creation";

#scope_file

Vertex :: struct {
    pos: Vector2;
    uv: Vector2;
}

InstanceData :: struct {
    position: Vector3;
    scale: Vector2;

    sprite_index: s32;
} #no_padding;

quad_vbo: GLuint;
quad_ebo: GLuint;
quad_vao: GLuint;
instance_vbo: GLuint;
sprite_shader_prog: GLuint;

sprite_draw_cmds: [..] Sprite_Draw_Cmd;

VERTEX_SHADER_TEXT :: #string DONE
#version 330 core

layout (location = 0) in vec2 vertex_pos;
layout (location = 1) in vec2 uv;

// per-instance data
layout (location = 2) in vec3 pos;
layout (location = 3) in vec2 scale;
layout (location = 4) in int spriteIndex;

out vec2 texCoord;

// per-instance data passthrough to fragment shader
flat out int sprite_index;

uniform mat4 projection;
uniform vec2 view_pos;

void main() {
    vec2 scaled_position = vertex_pos * scale;
    gl_Position = projection * vec4(pos.xy + scaled_position - view_pos, pos.z, 1.0);

    texCoord = uv;
    sprite_index = spriteIndex;
}
DONE

FRAGMENT_SHADER_TEXT :: #string DONE
#version 330 core

in vec2 texCoord;
flat in int sprite_index;

uniform int sprite_extent;
uniform sampler2D texture1;

out vec4 FragColor;

void main()
{
    ivec2 texture_size = textureSize(texture1, 0);
    ivec2 num_sprites = texture_size / sprite_extent;

    vec2 tile_size_uvs = float(sprite_extent) / vec2(texture_size);

    int x = sprite_index % num_sprites.x;
    int y = texture_size.y / sprite_extent - 1 - int((sprite_index * sprite_extent) / texture_size.x);

    vec2 uv_start = tile_size_uvs * vec2(x, y);

    vec2 uvs = uv_start + texCoord * tile_size_uvs;

    FragColor = texture(texture1, uvs);
} 
DONE

init_rendering_resources :: () {
    offset_of :: ($T: Type, $member: string) -> int {
        for type_info(T).members {
            if it.name == member return it.offset_in_bytes;
        }

        assert(false, "Type '%' does not have member '%'", T, member);
        return -1;
    }

    setup_vao_for_vertex_format :: (vao: GLuint) {
        glBindVertexArray(vao);

        // Vertex position
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) 0);

        // Vertex uvs
        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) size_of(Vector2));

        // instance data
        glEnableVertexAttribArray(2);
        glBindBuffer(GL_ARRAY_BUFFER, instance_vbo);
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(InstanceData), cast(*void) #run offset_of(InstanceData, "position"));
        glVertexAttribDivisor(2, 1);

        glEnableVertexAttribArray(3);
        glBindBuffer(GL_ARRAY_BUFFER, instance_vbo);
        glVertexAttribPointer(3, 2, GL_FLOAT, GL_FALSE, size_of(InstanceData), cast(*void) #run offset_of(InstanceData, "scale"));
        glVertexAttribDivisor(3, 1);

        glEnableVertexAttribArray(4);
        glBindBuffer(GL_ARRAY_BUFFER, instance_vbo);
        glVertexAttribIPointer(4, 1, GL_INT, size_of(InstanceData), cast(*void) #run offset_of(InstanceData, "sprite_index"));
        glVertexAttribDivisor(4, 1);

        glBindVertexArray(0);
    }

    // init the quad buffer
    {
        // 2 - 3
        // | / |
        // 0 - 1
        quad_vertices: [4] Vertex;
        quad_vertices[0] = .{.{-0.5, -0.5}, .{0., 0.}};
        quad_vertices[1] = .{.{+0.5, -0.5}, .{1., 0.}};
        quad_vertices[2] = .{.{-0.5, +0.5}, .{0., 1.}};
        quad_vertices[3] = .{.{+0.5, +0.5}, .{1., 1.}};

        quad_indices: [6] u32;
        quad_indices[0] = 0;
        quad_indices[1] = 1;
        quad_indices[2] = 3;
        quad_indices[3] = 0;
        quad_indices[4] = 3;
        quad_indices[5] = 2;

        glGenBuffers(1, *quad_vbo);
        glGenBuffers(1, *quad_ebo);
        glGenBuffers(1, *instance_vbo);
        glGenVertexArrays(1, *quad_vao);

        glBindVertexArray(quad_vao);

        glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
        glBufferData(GL_ARRAY_BUFFER, quad_vertices.count * size_of(Vertex), quad_vertices.data, GL_STATIC_DRAW);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quad_ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, quad_indices.count * size_of(u32), quad_indices.data, GL_STATIC_DRAW);

        setup_vao_for_vertex_format(quad_vao);

        glBindBuffer(GL_ARRAY_BUFFER, 0); //unbind
    }
    // init the shader program
    {
        v_shader_code := VERTEX_SHADER_TEXT;
        vertex_shader := glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vertex_shader, 1, *v_shader_code.data, null);
        glCompileShader(vertex_shader);

        f_shader_code := FRAGMENT_SHADER_TEXT;
        frag_shader := glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(frag_shader, 1, *f_shader_code.data, null);
        glCompileShader(frag_shader);

        defer glDeleteShader(vertex_shader);
        defer glDeleteShader(frag_shader);

        check_shader_status :: (shader: GLuint) -> bool {
            success: s32 = 0;
            glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
            if !success {
                compile_info: [512] u8;
                num: u32;
                glGetShaderInfoLog(shader, 512, *num, compile_info.data);

                compile_info_string: string = ---;
                compile_info_string.count = num;
                compile_info_string.data = compile_info.data;

                log_error("%", compile_info_string);
            }
            return cast(bool) success;
        }

        assert(check_shader_status(vertex_shader));
        assert(check_shader_status(frag_shader));

        sprite_shader_prog = glCreateProgram();
        glAttachShader(sprite_shader_prog, vertex_shader);
        glAttachShader(sprite_shader_prog, frag_shader);
        glLinkProgram(sprite_shader_prog);

        success: s32 = 0;
        glGetProgramiv(sprite_shader_prog, GL_LINK_STATUS, *success);
        if !success {
            compile_info: [512] u8;
            num: u32;
            glGetProgramInfoLog(sprite_shader_prog, 512, *num, compile_info.data);

            compile_info_string: string = ---;
            compile_info_string.count = num;
            compile_info_string.data = compile_info.data;

            log_error("%", compile_info_string);
            return;
        }
    }
}

set_shader_mat4 :: (shader: GLuint, name: *u8, m: Matrix4) {
    loc := glGetUniformLocation(shader, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniformMatrix4fv(loc, 1, GL_TRUE, *m._11);
}

set_shader_vec2 :: (shader: GLuint, name: *u8, v: Vector2) {
    loc := glGetUniformLocation(shader, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniform2fv(loc, 1, *v.x);
}

set_shader_uint :: (shader: GLuint, name: *u8, u: u32) {
    loc := glGetUniformLocation(shader, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniform1ui(loc, u);
}

set_shader_sint :: (shader: GLuint, name: *u8, u: s32) {
    loc := glGetUniformLocation(shader, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniform1i(loc, u);
}

#import "GL";
#import "Sort";