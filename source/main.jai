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

    init_ecs_events();

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

    // The following few lines should probably be moved elsewhere. They initialize some specific things which could maybe tied into a global world init function?
    main_view_camera = spawn_entity(*g_world, Position, Camera);
    add_component(*g_world, main_view_camera, Position);
    add_component(*g_world, main_view_camera, Camera);

    EVENT_PLAYER_ATTACK = register_event();
    EVENT_ON_PLAYER_ANIM_STATE_CHANGED = register_event();
    register_event_listener(EVENT_ON_PLAYER_ANIM_STATE_CHANGED, on_player_anim_state_changed);
    register_event_listener(EVENT_PLAYER_ATTACK, trigger_player_attack);

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
        cam_pos := get_component(*g_world, main_view_camera, Position);
        cam_pos.value = g_player_start;
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

update_positions :: (world: *World) {
    for query : Query(*Position, Velocity).{world = world} {
        positions := query.position;
        velocities := query.velocity;

        for 0..query.count-1 {
            positions[it].value += velocities[it].value * g_delta_time;
        }
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
    add_system(.PreUpdate, reset_collision_results);

    add_system(.OnUpdate, update_camera_projections);
    add_system(.OnUpdate, update_camera_positions);
    add_system(.OnUpdate, update_positions);
    add_system(.OnUpdate, update_player_anim_state);
    add_system(.OnUpdate, update_directions);

    add_system(.OnValidate, detect_collisions_system);
    add_system(.OnValidate, update_sprite_for_anim);

    add_system(.PostUpdate, resolve_collisions);
    add_system(.PostUpdate, update_player_positions_on_network);
    add_system(.PostUpdate, cleanup_player_controllers);
    
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
#load "gameplay/direction.jai";
#load "gameplay/player.jai";
#load "gameplay/attributes.jai";
#load "physics/collision.jai";
#load "debug_ui.jai";
#load "levels/ldtk_import.jai";
#load "animation/sprite_animation.jai";
#load "animation/anim_sm_player.jai";
#load "animation/animation_definitions.jai";
