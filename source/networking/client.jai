last_snapshot: State_Snapshot;
current_snapshot: State_Snapshot;

last_snapshot_time: float64;

client_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .CONNECTION_ESTABLISHED;
            conn_established: ConnectionEstablished_Packet;
            conn_established.existing_players.allocator = temp;
            conn_established.existing_enemies.allocator = temp;

            byte_buffer_read(buffer, *conn_established);

            assert(conn_established.node_id != INVALID_NODE_ID);

            g_client.local_client_id = conn_established.node_id;
            log("Local player was assigned id %", conn_established.node_id);

            g_local_player = init_player(conn_established.node_id, g_player_start);

            // we can ignore these if we're on the server
            if !is_server() {
                for player_data : conn_established.existing_players {
                    player := init_player(player_data.node_id, player_data.position);
                    log("Existing player initialized %", get_component(*g_world, player, Name).name);
                }

                for enemy_data : conn_established.existing_enemies {
                    enemy := spawn_enemy(*g_world, enemy_data.position, enemy_data.node_id, enemy_data.type);
                }
            }
        case .PLAYER_JOINED;
            player_joined: PlayerJoined_Packet;
            byte_buffer_read(buffer, *player_joined);

            init_player(player_joined.node_id, player_joined.position);

            log("New player has joined the game: %", player_joined.node_id);

        case .PLAYER_COMMANDS;
            player_commands_packet: Player_Commands_Packet;
            byte_buffer_read(buffer, *player_commands_packet);

            assert(player_commands_packet.node_id != g_client.local_client_id, 
                "The player should never receive a move packet for itself. We are allowing clients to be authoritative over their positions so this shouldn't happen.");

            entity, found := table_find(*entity_node_id_table, player_commands_packet.node_id);
            assert(found, "Received a player commands packet for an entity which is not registered in the networking system. How did this happen!?");

            player_commands := get_component(*g_world, entity, Player_Commands);
            assert(player_commands != null);
            << player_commands = player_commands_packet.commands;
        case .PLAYER_LEFT;
            player_left: PlayerLeft_Packet;
            byte_buffer_read(buffer, *player_left);

            entity, found := table_find(*entity_node_id_table, player_left.node_id);
            assert(found, "Received a Player Left packet for an entity which is not registered in the networking system. How did this happen!?");

            name := get_component(*g_world, entity, Name);
            if name {
                log("% has left the game.", name.name);
            }

            destroy_entity(*g_world, entity);
        case .SNAPSHOT;
            if !is_server() {
                snapshot_packet: State_Snapshot_Packet;
                byte_buffer_read(buffer, *snapshot_packet);

                last_snapshot = current_snapshot;
                current_snapshot = from_packet(snapshot_packet);
                last_snapshot_time = seconds_since_init();

                apply_snapshot(*g_world, current_snapshot);
                
                g_sim_frame_number = snapshot_packet.sequence_number;
            }
            //free(*snapshot);
        case;
    }
}

interpolate_states :: (world: *World, a: State_Snapshot, b: State_Snapshot, alpha: float) {
    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    state_a, success_a := table_find(*a.state, networking_ids[it].id);
                    state_b, success_b := table_find(*b.state, networking_ids[it].id);

                    if !success_a || !success_b then continue;

                    field_a: *Node_Field = null;
                    for * fields_it : state_a.fields {
                        if fields_it.field_id == #run component_type_id(%1).unique_id then field_a = fields_it;
                    }

                    field_b: *Node_Field = null;
                    for * fields_it : state_b.fields {
                        if fields_it.field_id == #run component_type_id(%1).unique_id then field_b = fields_it;
                    }
                    if field_a == null || field_b == null then continue;

                    field_a.data.only_note = "Interp";
                    field_b.data.only_note = "Interp";

                    a_data: %1;
                    b_data: %1;
                    field_a.data.cursor = 0;
                    byte_buffer_read(*field_a.data, *a_data);
                    field_b.data.cursor = 0;
                    byte_buffer_read(*field_b.data, *b_data);

                    datas[it] = lerp(a_data, b_data, alpha);
                }
            }
        DONE

        sb: String_Builder;

        for ALL_COMPONENT_TYPES {
            has_interp_fields := false;
            ti := cast(*Type_Info_Struct) it;
            for * member : ti.members {
                if has_note(member, "Sync") && has_note(member, "Interp") {
                    has_interp_fields = true;
                    break;
                }
            }

            if !has_interp_fields then continue;

            sbprint(*sb, INSERT_STRING, it);
        }

        return builder_to_string(*sb);
    }
}

apply_snapshot :: (world: *World, snapshot: State_Snapshot) {
    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    state, success := table_find(*snapshot.state, networking_ids[it].id);
                    // it's fine if we don't have an entry for the entity, since it may not exist on the client yet
                    // @todo: this should really be an assert tho
                    if !success then continue;

                    field: *Node_Field = null;
                    for * fields_it : state.fields {
                        if fields_it.field_id == #run component_type_id(%1).unique_id then field = fields_it;
                    }
                    assert(field != null);

                    field.data.only_note = "Sync";
                    field.data.cursor = 0;

                    byte_buffer_read(*field.data, *datas[it]);
                }
            }
        DONE

        sb: String_Builder;

        for ALL_COMPONENT_TYPES {
            has_sync_fields := false;
            ti := cast(*Type_Info_Struct) it;
            for * member : ti.members {
                if has_note(member, "Sync") {
                    has_sync_fields = true;
                    break;
                }
            }

            if !has_sync_fields then continue;

            sbprint(*sb, INSERT_STRING, it);
        }

        return builder_to_string(*sb);
    }
}