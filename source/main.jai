DEBUG :: true;

// Define both server and client for the Jai Language Server diagnostic build to ensure all symbols are visible.
#if #exists(JAILS_DIAGNOSTICS_BUILD) {
    SERVER :: true;
    CLIENT :: true;
}

// #todo: we probably want this value to vary so that the window size can't just show you more of the world.
// The number of tiles visible should mostly remain a constant value
PIXELS_PER_METER :: 64;

// @todo: move this to a singleton component
g_delta_time: float = 0.016;
g_smooth_delta_time: float = 0.016;
last_time: float64;

g_sim_timer: float64 = 0.016;
g_render_timer: float64 = 0.016;

TICK_RATE :: 64;
FIXED_TIMESTEP :: 1. / TICK_RATE;

g_should_exit: bool = false;

g_frame_number: u64 = 0;
g_current_tick: u32 = 0;

g_world: World;

Program_Args :: struct {
    ip: string = "127.0.0.1";
    port: u16 = 27015;
    host := false;
}

g_args: Program_Args;

main :: () {
    {
        success, args := parse_arguments(Program_Args);
        assert(success, "failed to parse program arguments!");
        g_args = args;
    }

    log_initialize();
    execute_unit_tests();

    ecs_world_init(*g_world);
    #if SERVER {
        entity_set_range(*g_world, 50000, 0);
    } else {
        entity_set_range(*g_world, 1000, 50000);
    }

    // set the working direction to be the root of the project (should always two directories up from the executable)
    working_dir := (tprint("%/../..", path_strip_filename(get_path_of_running_executable())));
    set_working_directory(working_dir);

    register_system_functions(*g_world);

    networking_init();

    #if SERVER {
        server_main();
    } else {
        client_main();
    }

    networking_shutdown();
}

using Basic :: #import "Basic";
using Random :: #import "Random";
#import "Sort";
#import "File";
#import "Process";

// #import "tracy"(IMPORT_MODE = .CLIENT);

#import "System";


#if CLIENT {
#load "hal/hal_input.jai";
#load "debug_ui/debug_ui.jai";
#load "game_ui/game_ui.jai";
#load "rendering/camera.jai";
#load "hal/hal_window.jai";
#load "debug_ui/imgui.jai";
#load "rendering/rendering.jai";
#load "client_main.jai";
} else #if SERVER {
#load "server_main.jai";
}

#load "utils/utils.jai";
#load "math/math.jai";
#load "logging.jai";
#load "networking/networking.jai";
#load "unit_test.jai";
#load "assets.jai";
#load "ecs/ecs.jai";
#load "gameplay/gameplay.jai";
#load "items/items.jai";
#load "physics/collision.jai";
#load "levels/level.jai";
#load "animation/sprite_animation.jai";
#load "animation/player_anim_sm.jai";
#load "animation/skeleton_anim_sm.jai";
#load "animation/bat_anim_sm.jai";
#load "animation/animation_definitions.jai";