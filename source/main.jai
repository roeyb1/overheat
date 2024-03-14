g_delta_time: float = 0.013;
g_smooth_delta_time: float = 0.013;

g_should_exit: bool = false;

g_frame_number: u64 = 0;

ExitGame :: (key_state: Key_Current_State) {
    g_should_exit = true;
} @RegisterInputAction

main :: () {
    log_initialize();

    if !execute_unit_tests() {
        log_error("Unit tests failed! See log for more information.");
    }

    // set the working direction to be the root of the project (should always two directories up from the executable)
    working_dir := (tprint("%/../..", path_strip_filename(get_path_of_running_executable())));
    set_working_directory(working_dir);

    rendering_init();
    input_manager_initialize();
    networking_init();

    load_all_assets();

    last_time := seconds_since_init();

    // Only update networking while we attempt to connect to the server and don't yet have a player:
    while g_local_player == null {
        networking_update();
        input_manager_update();
        application_window_update();

        // #todo: re-enable this when we can support drawing 0 sprites
        rendering_begin_frame();
        draw_scene(*main_view_camera);

        {
            //Simp.set_shader_for_text();
            //text_width := Simp.prepare_text(g_large_font, "Connecting to server...");
            //Simp.draw_prepared_text(g_large_font, (g_window_width - text_width) / 2, g_window_height / 2);
        }

        rendering_end_frame();
        reset_temporary_storage();

        g_frame_number += 1;
    }

    main_view_camera.entity_to_track = g_local_player;

    while !g_should_exit {
        networking_update();
        input_manager_update();
        application_window_update();

        rendering_begin_frame();

        now := seconds_since_init();
        g_delta_time = cast(float) (now - last_time);
        smooth_delta_time_weight := ifx g_frame_number < 16 then 1. else 1. / 16.;
        g_smooth_delta_time = smooth_delta_time_weight * g_delta_time + (1. - smooth_delta_time_weight) * g_smooth_delta_time;
        last_time = now;

        simulate(g_delta_time);

        update_camera_position(*main_view_camera, g_delta_time);

        draw_scene(*main_view_camera);

        rendering_end_frame();

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();

        g_frame_number += 1;
    }

    networking_shutdown();
    input_manager_shutdown();
    rendering_shutdown();
}

simulate :: (delta_time: float64) {
    // update player position based on velocity:
    if update_player_controller() {
        // #todo: send a packet indicating the movement to other clients:
        g_local_player.position += g_local_player.velocity * cast(float32) delta_time;

        player_moved: PlayerMove_Packet = ---;
        player_moved.player_id = g_local_player.player_id;
        player_moved.new_position = g_local_player.position;

        networking_send_packet(*player_moved);;
    }
}

draw_scene :: (camera: *Camera) {
    // Draw a temporary background
    {
        ground_sprite: Sprite;
        ground_sprite.sheet = g_dungeon_tiles;
        ground_sprite.z_order = -1;
        ground_sprite.index = 256;

        for x : -20..20 {
            for y : -20..20 {
                draw_sprite(camera, *ground_sprite, .{xx x,  xx y });
            }
        }
    }

    // Draw players
    {
        for :Player_It g_world {
            draw_sprite(camera, *it.sprite, it.position);
        }
    }

    render_scene(camera);
}


#import "Basic";
#import "Input";

#load "utils.jai";
#load "logging.jai";
#load "networking.jai";
#load "rendering.jai";
#load "player.jai";
#load "input.jai";
#load "unit_test.jai";
#load "world.jai";
#load "entities.jai";
#load "camera.jai";
#load "assets.jai";
#load "shader_compilation.jai";