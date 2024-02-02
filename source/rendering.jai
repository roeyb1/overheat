#scope_export

game_window: Window_Type;
window_width, window_height: s32;

rendering_init :: () -> bool {
    log("Initialized rendering systems...");

    game_window = create_window(800, 600, "Sapped");
    window_width, window_height = Simp.get_render_dimensions(game_window);

    Simp.set_render_target(game_window);

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
            window_width = it.width;
            window_height = it.height;
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

Simp :: #import "Simp";
#import "Window_Creation";