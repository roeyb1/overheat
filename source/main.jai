DEBUG :: true;

// @todo: move this to a singleton component
g_delta_time: float = 0.016;
g_smooth_delta_time: float = 0.016;
last_time: float64;
g_interp_alpha: float = 0.;

FIXED_TIMESTEP :: 0.016;

g_should_exit: bool = false;

g_frame_number: u64 = 0;

g_world: World;

g_local_player: Entity;
main_view_camera: Entity;

main :: () {
    log_initialize();

    execute_unit_tests();

    // set the working direction to be the root of the project (should always two directories up from the executable)
    working_dir := (tprint("%/../..", path_strip_filename(get_path_of_running_executable())));
    set_working_directory(working_dir);

    register_system_functions();

    window_system_init();
    imgui_init();

    rendering_init();
    networking_init();

    load_all_assets();
    import_ldtk_level(*g_world);

    last_time = seconds_since_init();

    // The following few lines should probably be moved elsewhere. They initialize some specific things which could maybe tied into a global world init function?
    main_view_camera = spawn_entity(*g_world, Position, Camera);

    accumulated_time := 0.0;

    // Only update networking while we attempt to connect to the server and don't yet have a player:
    while g_client.local_client_id == INVALID_NETWORKING_ID {
        FrameMark();

        now := seconds_since_init();
        g_delta_time = cast(float) (now - last_time);
        smooth_delta_time_weight := ifx g_frame_number < 16 then 1. else 1. / 16.;
        g_smooth_delta_time = smooth_delta_time_weight * g_delta_time + (1. - smooth_delta_time_weight) * g_smooth_delta_time;
        last_time = now;

        hal_input_update();
        window_system_update();

        if g_should_exit {
            break;
        }

        networking_update();

        rendering_begin_frame();
        ImGui.NewFrame();

        execute(*g_world, .Init);

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
        << cam_pos = .{ g_player_start };
        camera.entity_to_track = g_local_player;
    }
    

    while true {
        FrameMark();

        now := seconds_since_init();
        g_delta_time = cast(float) (now - last_time);
        smooth_delta_time_weight := ifx g_frame_number < 16 then 1. else 1. / 16.;
        g_smooth_delta_time = smooth_delta_time_weight * g_delta_time + (1. - smooth_delta_time_weight) * g_smooth_delta_time;
        last_time = now;

        accumulated_time += g_delta_time;

        hal_input_update();
        window_system_update();

        if g_should_exit {
            break;
        }

        networking_update();

        rendering_begin_frame();
        ImGui.NewFrame();

        render_debug_ui();

        execute(*g_world, .Init);

        execute(*g_world, .OnLoad);
        execute(*g_world, .PostLoad);

        // Run simulation on a fixed timestep for determinism 
        while accumulated_time >= FIXED_TIMESTEP {
            execute(*g_world, .PreUpdate);
            execute(*g_world, .OnUpdate);
            execute(*g_world, .OnValidate);
            execute(*g_world, .PostUpdate);
            accumulated_time -= FIXED_TIMESTEP;
        }
        g_interp_alpha = accumulated_time / FIXED_TIMESTEP;

        execute(*g_world, .PreRender);
        execute(*g_world, .OnRender);


        rendering_end_frame();

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();

        g_frame_number += 1;
    }

    networking_shutdown();
    rendering_shutdown();
}

update_positions :: (q: Query) {
    positions := query_get(q, Position);
    velocities := query_get(q, Velocity);

    for 0..q.count-1 {
        positions[it].value = positions[it] + velocities[it] * FIXED_TIMESTEP;
    }
} @System(OnUpdate) @Write(Position) @Read(Velocity)

render_scene :: (q: Query) {
    pos := get_component(q.world, main_view_camera, Position);
    cam := get_component(q.world, main_view_camera, Camera);

    render_scene(cam.projection, pos);
} @System(OnRender) @Write() @Read(Position,Camera)

using Basic :: #import "Basic";
using Random :: #import "Random";

#import "tracy"(IMPORT_MODE = .CLIENT);

#import "System";

#load "utils/utils.jai";
#load "math.jai";
#load "logging.jai";
#load "networking.jai";
#load "hal/hal_window.jai";
#load "hal/hal_input.jai";
#load "imgui.jai";
#load "rendering/rendering.jai";
#load "rendering/camera.jai";
#load "unit_test.jai";
#load "assets.jai";
#load "ecs/world.jai";
#load "ecs/relationships.jai";
#load "ecs/system.jai";
#load "ecs/singleton.jai";
#load "gameplay/components.jai";
#load "gameplay/position_interp.jai";
#load "gameplay/direction.jai";
#load "gameplay/input.jai";
#load "gameplay/player.jai";
#load "gameplay/attributes.jai";
#load "gameplay/damage.jai";
#load "gameplay/enemy.jai";
#load "gameplay/follower.jai";
#load "physics/collision.jai";
#load "debug_ui.jai";
#load "levels/ldtk_import.jai";
#load "animation/sprite_animation.jai";
#load "animation/player_anim_sm.jai";
#load "animation/skeleton_anim_sm.jai";
#load "animation/bat_anim_sm.jai";
#load "animation/animation_definitions.jai";
