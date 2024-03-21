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

    recompute_camera_projection(*main_view_camera);

    log("Rendering systems initialized successfully");
    return true;
}

rendering_shutdown :: () {
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

#scope_file
DrawBucket :: struct {
    start: u64;
    count: u64;
    sprite_sheet: *SpriteSheet;
}
#scope_export

commandBuffers: [MAX_FRAMES_IN_FLIGHT] VkCommandBuffer;

render_scene :: (camera: *Camera) {
    rg := *g_render_graph;
    rdg_next_frame(rg);

    // ??

    rdg_execute(rg);


    swapchain_present(rg.semaphores[RHIQueueIndex.GRAPHICS], rg.semaphore_values[RHIQueueIndex.GRAPHICS], rg.semaphores[RHIQueueIndex.GRAPHICS], rg.semaphore_values[RHIQueueIndex.GRAPHICS] + 1);
    rg.semaphore_values[RHIQueueIndex.GRAPHICS] += 1;
}

#import "Window_Creation";

#scope_file

#load "render_graph.jai";
#load "../rhi/rhi.jai";

#import "Sort";
#import "File";

#if OS == .WINDOWS {
    #import "Windows";
}