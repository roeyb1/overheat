#scope_export

game_window: Window_Type;
g_window_width, g_window_height: s32;

g_large_font: *Simp.Dynamic_Font;
g_grid_texture: Simp.Texture;

main_view_camera: Camera;

rendering_init :: () -> bool {
    log("Initialized rendering systems...");

    game_window = create_window(800, 600, "Overheat");
    g_window_width, g_window_height = Simp.get_render_dimensions(game_window);

    Simp.set_render_target(game_window);

    main_view_camera.width = xx g_window_width;
    main_view_camera.height = xx g_window_height;

    g_large_font = Simp.load_font("assets", "monogram.ttf", 38);

    assert(Simp.texture_load_from_file(*g_grid_texture, "assets/grid.png"));

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

            main_view_camera.width = xx g_window_width;
            main_view_camera.height = xx g_window_height;
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