#assert CLIENT;

local_server_started := false;
server_process: Process;

start_local_server :: () {
    assert(!local_server_started);
    
    #if OS == .WINDOWS {
        binary_path :: "bin/win";
    }
    #if OS == .LINUX {
        binary_path :: "bin/linux";
    }

    local_server_started = create_process(*server_process, tprint("%/overheat-server", binary_path), "-port", tprint("%", g_args.port));
    assert(local_server_started);
}

client_main :: () {
    if g_args.host {
        start_local_server();
    }

    window_system_init();
    imgui_init();

    rendering_init();

    load_all_assets();

    last_time = seconds_since_init();

    // The following few lines should probably be moved elsewhere. They initialize some specific things which could maybe tied into a global world init function?
    viewport := ecs_singleton_get(*g_world, Game_Viewport);
    viewport.main_camera = entity_spawn(*g_world, Position, Camera);

    while true {
        //FrameMark();

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

        render_debug_ui();

        if g_client.local_client_id == INVALID_NODE_ID {
            if !ImGui.IsPopupOpen("Connecting...") {
                ImGui.OpenPopup("Connecting...");
            }
            if ImGui.BeginPopupModal("Connecting...", null, .AlwaysAutoResize | .NoMove) {
                ImGui.Text("Connecting to server...");
                if !local_server_started && ImGui.Button("Host", .{ ImGui.GetContentRegionAvail().x, 0}) {
                    start_local_server();
                }
                ImGui.EndPopup();
            }
        }

        execute(*g_world, .Init);

        if g_client.local_client_id != INVALID_NODE_ID {
            expected_tick := get_ticks_from_time(smooth_server_time);
            while g_current_tick < expected_tick {
                last_prediction_time = smooth_server_time;

                scoped_smooth_timer(*g_sim_timer, 1. / 16.);
                scoped_guard(*g_only_simulate_local_player, true);

                if g_enable_prediction && is_prediction_valid(0) {
                    apply_prediction_state(*g_world, current_prediction());
                }
                g_current_tick += 1;

                execute(*g_world, .OnLoad);
                execute(*g_world, .PostLoad);

                if g_enable_prediction {
                    execute(*g_world, .PreUpdate);
                    execute(*g_world, .OnUpdate);
                    execute(*g_world, .OnValidate);
                    execute(*g_world, .PostUpdate);

                    push_new_prediction();
                }
            }

            if last_received_snapshot_tick != -1 && previous_snapshot().tick != 0 && current_snapshot().tick != 0 {
                server_interp_alpha := clamp(cast(float)(server_interp_time - last_known_server_time) / FIXED_TIMESTEP, 0, 1);
                interpolate_server_states(*g_world, previous_snapshot(), current_snapshot(), server_interp_alpha);
            }

            if g_enable_prediction && is_prediction_valid(-1) && is_prediction_valid(0) {
                prediction_alpha := clamp(cast(float)(smooth_server_time - last_prediction_time) / FIXED_TIMESTEP, 0, 1);
                interpolate_prediction_state(*g_world, previous_prediction(), current_prediction(), prediction_alpha);
            }
        }

        {
            scoped_smooth_timer(*g_render_timer, 1. / 16.);

            execute(*g_world, .PreRender);
            execute(*g_world, .OnRender);

            rendering_end_frame();
        }

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();

        g_frame_number += 1;
    }

    rendering_shutdown();
}