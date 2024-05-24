DEBUG :: true;

g_delta_time: float = 0.013;
g_smooth_delta_time: float = 0.013;
last_time: float64;

g_should_exit: bool = false;

g_frame_number: u64 = 0;

g_world: World;

g_local_player: Entity;
main_view_camera: Entity;

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

    window_system_init();
    imgui_init();

    rendering_init();
    input_map_init();
    networking_init();

    load_all_assets();
    import_ldtk_level(*g_world);

    last_time = seconds_since_init();

    main_view_camera = spawn_entity(*g_world);
    add_component(*g_world, main_view_camera, Position);
    add_component(*g_world, main_view_camera, Camera);

    {
        light0 := spawn_entity(*g_world, Velocity);
        add_component(*g_world, light0, Position, .{value = .{0., 0.}});
        add_component(*g_world, light0, Point_Light, .{intensity = 1., color = .{ 255. / 255., 147. / 255., 41./255.}, radius = 15.});

        light1 := spawn_entity(*g_world, Velocity);
        add_component(*g_world, light1, Position, .{value = .{-3., -3.}});
        add_component(*g_world, light1, Point_Light, .{intensity = 1., color = .{ 255. / 255., 147. / 255., 41./255.}, radius = 15.});

        light2 := spawn_entity(*g_world, Velocity);
        add_component(*g_world, light2, Position, .{value = .{-3., -5.}});
        add_component(*g_world, light2, Point_Light, .{intensity = 1., color = .{ 255. / 255., 147. / 255., 41./255.}, radius = 15.});
    }

    // Only update networking while we attempt to connect to the server and don't yet have a player:
    while g_client.local_client_id == INVALID_NETWORKING_ID {
        FrameMark();

        input_system_update();
        window_system_update();

        if g_should_exit {
            break;
        }

        networking_update();
        input_map_update();

        rendering_begin_frame();
        ImGui.NewFrame();

        execute(*g_world, .Init);
        execute(*g_world, .OnLoad);
        execute(*g_world, .PostLoad);

        // show connecting popup modal
        if !ImGui.IsPopupOpen("Connecting...") {
            ImGui.OpenPopup("Connecting...");
        }
        if ImGui.BeginPopupModal("Connecting...", null, .AlwaysAutoResize | .NoMove) {
            ImGui.Text("Connecting to server...");
            ImGui.EndPopup();
        }

        execute(*g_world, .PreRender);
        execute(*g_world, .OnRender);

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

        input_system_update();
        window_system_update();

        if g_should_exit {
            break;
        }

        networking_update();
        input_map_update();

        rendering_begin_frame();
        ImGui.NewFrame();

        render_debug_ui();

        execute(*g_world, .Init);
        execute(*g_world, .OnLoad);
        execute(*g_world, .PostLoad);
        execute(*g_world, .PreUpdate);
        execute(*g_world, .OnUpdate);
        execute(*g_world, .OnValidate);
        execute(*g_world, .PostUpdate);
        execute(*g_world, .PreRender);
        execute(*g_world, .OnRender);


        rendering_end_frame();

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();

        g_frame_number += 1;
    }

    networking_shutdown();
    input_map_shutdown();
    rendering_shutdown();
}

animate_lights :: (world: *World) {
    for Query(*Velocity, Point_Light).{world = world} {
        // animate any lights that are not attached to a player:
        if get_component(world, it_index, Player) == null {
            dx := random_get_zero_to_one() - 0.5;
            dy := random_get_zero_to_one() - 0.5;
            it.velocity.value += Vector2.{dx, dy} * 5.0 * g_delta_time;
        }
    }
}

update_positions :: (world: *World) {
    for Query(*Position, Velocity).{world = world} {
        it.position.value += it.velocity.value * g_delta_time;
    }
} @System

render_imgui :: (world: *World) {
    ImGui.Render();
}@System

render_scene :: (world: *World) {
    pos := get_component(world, main_view_camera, Position);
    cam := get_component(world, main_view_camera, Camera);

    render_scene(cam.projection, pos);
}@System

// #todo [roey]: generate this function at compile time?
register_all_systems :: () {
    add_system(System_Phase.OnLoad, (world: *World) {
        now := seconds_since_init();
        g_delta_time = cast(float) (now - last_time);
        smooth_delta_time_weight := ifx g_frame_number < 16 then 1. else 1. / 16.;
        g_smooth_delta_time = smooth_delta_time_weight * g_delta_time + (1. - smooth_delta_time_weight) * g_smooth_delta_time;
        last_time = now;
    });

    add_system(.PreUpdate, update_player_controllers);
    add_system(.PreUpdate, animate_lights);

    add_system(.OnUpdate, update_camera_projections);
    add_system(.OnUpdate, update_camera_positions);
    add_system(.OnUpdate, update_positions);

    add_system(.OnValidate, detect_collisions_system);

    add_system(.PostUpdate, update_player_positions_on_network);
    add_system(.PostUpdate, cleanup_player_controllers);
    add_system(.PostUpdate, cleanup_collision_results_system);

    add_system(.PreRender, render_imgui);

    add_system(.OnRender, render_scene);

    build_system_dependency_graphs();
}



using Basic :: #import "Basic";
#import "tracy"(IMPORT_MODE = .CLIENT);
using Random :: #import "Random";

#load "utils/utils.jai";
#load "math.jai";
#load "logging.jai";
#load "networking.jai";
#load "window.jai";
#load "imgui.jai";
#load "rendering/rendering.jai";
#load "rendering/camera.jai";
#load "input.jai";
#load "input_mapping.jai";
#load "unit_test.jai";
#load "assets.jai";
#load "ecs/world.jai";
#load "ecs/system.jai";
#load "gameplay/components.jai";
#load "gameplay/player.jai";
#load "gameplay/attributes.jai";
#load "physics/collision.jai";
#load "debug_ui.jai";
#load "levels/ldtk_import.jai";

