#assert SERVER;

server_main :: () {
    import_ldtk_level(*g_world);

    last_time = seconds_since_init();

    while true {
        now := seconds_since_init();
        g_delta_time = cast(float) (now - last_time);
        smooth_delta_time_weight := ifx g_frame_number < 16 then 1. else 1. / 16.;
        g_smooth_delta_time = smooth_delta_time_weight * g_delta_time + (1. - smooth_delta_time_weight) * g_smooth_delta_time;
        last_time = now;

        if g_should_exit {
            break;
        }

        networking_update();

        // Run simulation on a fixed timestep for determinism 
        expected_tick := get_ticks_from_time(xx seconds_since_init());
        while g_current_tick < expected_tick {
            g_current_tick += 1;

            FrameMark();
            scoped_smooth_timer(*g_sim_timer, 1. / 16.);

            execute(*g_world, .PreUpdate);
            execute(*g_world, .OnUpdate);
            execute(*g_world, .OnValidate);
            execute(*g_world, .PostUpdate);

            push_new_snapshot(generate_full_snapshot(*g_world));

            delta := generate_delta_snapshot(*g_world, get_snapshot(-1), get_snapshot(0));

            snapshot_packet := to_packet(*delta);
    
            for * g_server.clients {
                input_ring, found := table_find(*per_player_input_rings, it.node_id);
                assert(found);
                player_state_update: Player_State_Snapshot_Packet;
                player_state_update.data = snapshot_packet;
                player_state_update.input = input_ring[g_current_tick % input_ring.count];
                networking_send_packet(it, *player_state_update);
            }

            free(*delta);
        }

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();
    }
}
