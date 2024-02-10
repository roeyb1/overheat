#scope_export

game_window: Window_Type;
g_window_width, g_window_height: s32;

main_view_camera: Camera;

Sprite :: struct {
    sheet: *SpriteSheet;
    index: u32;
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
}

draw_sprite :: (camera: *Camera, sprite: *Sprite, position: Vector2) {
    glUseProgram(sprite_shader_prog);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    glEnable(GL_TEXTURE_2D);

    glBindVertexArray(quad_vao);
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);


    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, sprite.sheet.texture.gl_handle);

    set_shader_mat4(sprite_shader_prog, "projection", camera.projection);
    set_shader_vec2(sprite_shader_prog, "view_pos", camera.position);
    set_shader_vec2(sprite_shader_prog, "pos", position);
    set_shader_vec2(sprite_shader_prog, "scale", .{1., 1.});
    set_shader_uint(sprite_shader_prog, "sprite_index", sprite.index);
    set_shader_uint(sprite_shader_prog, "sprite_extent", sprite.sheet.extent);

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
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

quad_vbo: GLuint;
quad_ebo: GLuint;
quad_vao: GLuint;
sprite_shader_prog: GLuint;

VERTEX_SHADER_TEXT :: #string DONE
#version 330 core

layout (location = 0) in vec2 vertex_pos;
layout (location = 1) in vec2 uv;

out vec2 texCoord;

uniform mat4 projection;
uniform vec2 view_pos;
uniform vec2 scale;
uniform vec2 pos;

void main() {
    vec2 scaled_position = vertex_pos * scale;
    gl_Position = projection * vec4(pos + scaled_position - view_pos, 0.0, 1.0);

    texCoord = uv;
}
DONE

FRAGMENT_SHADER_TEXT :: #string DONE
#version 330 core

in vec2 texCoord;
uniform sampler2D texture1;

uniform uint sprite_index;
uniform uint sprite_extent;

out vec4 FragColor;

void main()
{
    ivec2 texture_size = textureSize(texture1, 0);
    ivec2 num_sprites = texture_size / int(sprite_extent);

    vec2 tile_size_uvs = float(sprite_extent) / vec2(texture_size);

    int x = int(sprite_index) % num_sprites.x;
    int y = texture_size.y / int(sprite_extent) - 1 - int(int(sprite_index * sprite_extent) / texture_size.x);

    vec2 uv_start = tile_size_uvs * vec2(x, y);

    vec2 uvs = uv_start + texCoord * tile_size_uvs;

    FragColor = texture(texture1, uvs);
    //FragColor = vec4(uvs, 0., 1.0);
} 
DONE

init_rendering_resources :: () {
    setup_vao_for_vertex_format :: (vao: GLuint) {
        glBindVertexArray(vao);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) 0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) size_of(Vector2));
        glEnableVertexAttribArray(1);
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

#import "GL";