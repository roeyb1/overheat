delta_time: float64 = 0.013;

g_should_exit: bool = false;

g_frame_number: u8 = 0;

ExitGame :: (key_state: Key_Current_State) {
    g_should_exit = true;
} @RegisterInputAction

main :: () {
    log_initialize();

    execute_unit_tests();

    // set the working direction to be the root of the project (should always one directory up from the executable)
    working_dir := (tprint("%/..", path_strip_filename(get_path_of_running_executable())));
    set_working_directory(working_dir);

    rendering_init();
    input_manager_initialize();
    networking_init();

    last_time := seconds_since_init();

    // Only update networking while we attempt to connect to the server and don't yet have a player:
    while g_local_player == null {
        networking_update();
        input_manager_update();

        rendering_begin_frame();

        rendering_end_frame();
        reset_temporary_storage();
    }

    while !g_should_exit {
        networking_update();

        input_manager_update();

        rendering_begin_frame();

        now := seconds_since_init();
        delta_time = (now - last_time);
        last_time = now;

        simulate(delta_time);

        draw_scene();

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

draw_scene :: () {
    Simp.set_shader_for_color(true);
    for :Player_It g_world {
        quad_size: Vector2 = .{32., 32.};
        center := it.position;
        bottom_left := center - quad_size;
        top_right := center + quad_size;

        color := ifx it.player_id == g_client.local_client_id {
            Vector4.{0.227, 0.204, 0.921, 1.};
        } else {
            Vector4.{1., 0., 0., 1.};
        }

        Simp.immediate_quad(bottom_left.x, bottom_left.y, top_right.x, top_right.y, color);
    }
}


#import "Basic";
#import "Input";

#load "logging.jai";
#load "networking.jai";
#load "rendering.jai";
#load "player.jai";
#load "input.jai";
#load "unit_test.jai";
#load "world.jai";
#load "entities.jai";