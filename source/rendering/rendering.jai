#scope_export

MEMORY_LEAK_CHECK :: false;

game_window: Window_Type;
g_window_width: u32 = 800;
g_window_height: u32 = 600;

main_view_camera: Camera;

Sprite :: struct {
    sheet: *SpriteSheet = null;
    scale: Vector2 = .{1, 1};
    index: s32 = 0;
    z_order: s8 = 0;
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

    game_window = create_window(g_window_width, g_window_height, "Overheat");

    init_rhi();
    init_surface();
    init_device();
    init_swapchain(g_window_width, g_window_height);

    graphics_semaphore = create_semaphore(0);

    init_bindless_descriptor_set();

    cmd_pool = create_cmd_pool(graphics_queue);
    for 0..cmd_lists.count-1 {
        cmd_lists[it] = allocate_cmd_list(cmd_pool);
    }

    recompute_camera_projection(*main_view_camera);

    log("Rendering systems initialized successfully");
    return true;
}

rendering_shutdown :: () {
    // free cmd lists?
    reset_cmd_pool(cmd_pool);

    destroy_bindless_descriptor_set();

    destroy_semaphore(graphics_semaphore);

    destroy_swapchain();
    destroy_device();
    destroy_surface();
    destroy_rhi();

    log("Rendering systems shutdown successfully");
}

application_window_update :: () {
    update_window_events();

    for get_window_resizes() {
        if it.window == game_window {
            resize_swapchain(g_window_width, g_window_height);

            recompute_camera_projection(*main_view_camera);
        }
    }

    for events_this_frame {
        if it.type == .QUIT then g_should_exit = true;
    }
}

rendering_begin_frame :: () {
    get_swapchain_image_index();
}   

rendering_end_frame :: () {
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

graphics_semaphore: RHISemaphore;
graphics_semaphore_value: u64 = 0;

commandBuffers: [MAX_FRAMES_IN_FLIGHT] VkCommandBuffer;

render_scene :: (camera: *Camera) {
    swapchain_present(graphics_semaphore, graphics_semaphore_value, graphics_semaphore, graphics_semaphore_value + 1);
    graphics_semaphore_value += 1;
}

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

sprite_draw_cmds: [..] Sprite_Draw_Cmd;

#scope_file

#load "render_graph.jai";
#load "../rhi/rhi.jai";
#load "rendering_resources.jai";

#import "Sort";
#import "File";

#if OS == .WINDOWS {
    #import "Windows";
}