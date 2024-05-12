DEBUG :: true;

g_delta_time: float = 0.013;
g_smooth_delta_time: float = 0.013;

g_should_exit: bool = false;

g_frame_number: u64 = 0;

g_world: World;

g_local_player: Entity = INVALID_EID;
main_view_camera: Entity = INVALID_EID;

ExitGame :: (key_state: Key_Current_State) {
    g_should_exit = true;
} @RegisterInputAction

main :: () {
    log_initialize();

    execute_unit_tests();

    // set the working direction to be the root of the project (should always two directories up from the executable)
    working_dir := (tprint("%/../..", path_strip_filename(get_path_of_running_executable())));
    set_working_directory(working_dir);

    register_all_systems();

    rendering_init();
    input_manager_initialize();
    networking_init();

    load_all_assets();

    last_time := seconds_since_init();

    main_view_camera = spawn_entity(*g_world);
    add_component(*g_world, main_view_camera, Position);
    add_component(*g_world, main_view_camera, Camera);

    // Only update networking while we attempt to connect to the server and don't yet have a player:
    while g_client.local_client_id == INVALID_NETWORKING_ID {
        FrameMark();

        networking_update();
        input_manager_update();

        application_window_update();

        if g_should_exit {
            break;
        }

        rendering_begin_frame();

        execute(*g_world, system_groups[System_Phase.INIT]);
        execute(*g_world, system_groups[System_Phase.PRESENT]);
        execute(*g_world, system_groups[System_Phase.CLEANUP]);

        rendering_end_frame();
        reset_temporary_storage();

        g_frame_number += 1;
    }

    {
        camera := get_component(*g_world, main_view_camera, Camera);
        camera.entity_to_track = g_local_player;
    }
    

    while true {
        FrameMark();

        networking_update();
        input_manager_update();
        application_window_update();

        if g_should_exit {
            break;
        }

        now := seconds_since_init();
        g_delta_time = cast(float) (now - last_time);
        smooth_delta_time_weight := ifx g_frame_number < 16 then 1. else 1. / 16.;
        g_smooth_delta_time = smooth_delta_time_weight * g_delta_time + (1. - smooth_delta_time_weight) * g_smooth_delta_time;
        last_time = now;

        rendering_begin_frame();

        execute(*g_world, system_groups[System_Phase.INIT]);
        execute(*g_world, system_groups[System_Phase.SIMULATE]);
        execute(*g_world, system_groups[System_Phase.PRESENT]);
        execute(*g_world, system_groups[System_Phase.CLEANUP]);

        rendering_end_frame();

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();

        g_frame_number += 1;
    }

    networking_shutdown();
    input_manager_shutdown();
    rendering_shutdown();
}


// #todo [roey]: generate this function at compile time?
register_all_systems :: () {

    // SIMULATE phase systems:
   
    add_system(*system_groups[System_Phase.SIMULATE], .{update_player_controllers});
    add_system(*system_groups[System_Phase.SIMULATE], .{update_camera_projections});
    add_system(*system_groups[System_Phase.SIMULATE], .{update_camera_positions});

    // Update positions from velocities
    add_system(*system_groups[System_Phase.SIMULATE], .{(world: *World) {
        for Query(*Position, *Velocity).{world = world} {
            it.position.pos += it.velocity.vel * g_delta_time;
        }
    }});

    add_system(*system_groups[System_Phase.SIMULATE], .{update_player_positions_on_network});


    // PRESENT phase systems:

    add_system(*system_groups[System_Phase.PRESENT], .{(world: *World) {
        pos := get_component(world, main_view_camera, Position);
        cam := get_component(world, main_view_camera, Camera);

        render_scene(cam.projection, pos);
    }});

    // CLEANUP phase systems:

    add_system(*system_groups[System_Phase.CLEANUP], .{cleanup_player_controllers});
}



#import "Basic";
#import "Input";
#import "tracy"(IMPORT_MODE = .CLIENT);

#load "utils.jai";
#load "logging.jai";
#load "networking.jai";
#load "rendering/rendering.jai";
#load "rendering/camera.jai";
#load "input.jai";
#load "unit_test.jai";
#load "assets.jai";
#load "ecs/world.jai";
#load "ecs/query.jai";
#load "ecs/system.jai";
#load "gameplay/components.jai";
#load "gameplay/player.jai";
#load "gameplay/attributes.jai";
