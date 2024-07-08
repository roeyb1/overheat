Client :: struct {
    endpoint: IPAddr;
    connection: NetConnection;

    should_disconnect: bool = false;

    local_client_id: Node_ID = INVALID_NODE_ID;
}
g_client: Client;

server_snapshots: [..] State_Snapshot;
prediction_snapshot: State_Snapshot;

last_snapshot_time: float64;

predict_next_frame := false;

previous_snapshot :: () -> *State_Snapshot {
    return *server_snapshots[0];
}

current_snapshot :: () -> *State_Snapshot {
    return *server_snapshots[1];
}

client_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .CONNECTION_ESTABLISHED;
            conn_established: ConnectionEstablished_Packet;

            byte_buffer_read(buffer, *conn_established);

            assert(conn_established.node_id != INVALID_NODE_ID);

            g_client.local_client_id = conn_established.node_id;
            g_sim_frame_number = conn_established.sequence_number;
            log("Local player was assigned id %", conn_established.node_id);

            snapshot := from_packet(conn_established.initial_snapshot);
            array_add(*server_snapshots, snapshot);
            array_add(*server_snapshots, from_packet(conn_established.initial_snapshot));
            last_snapshot_time = seconds_since_init();

            apply_full_snapshot(*g_world, snapshot);

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
        case .SNAPSHOT;
            snapshot_packet: State_Snapshot_Packet;
            byte_buffer_read(buffer, *snapshot_packet);

            if server_snapshots.count > 1 then {
                free(previous_snapshot());
                array_ordered_remove_by_index(*server_snapshots, 0);
            }

            // when we receive a new delta from the server:
            // - apply the delta to the world state
            // - build a new full snapshot  <--- @todo: this part is really slow and stupid, we should be able to apply the delta on top of the state
            // - store that snapshot for interpolation purposes

            delta := from_packet(snapshot_packet);
            apply_delta_snapshot(*g_world, delta);
            free(*delta);
            new_snapshot := generate_full_snapshot(*g_world);

            array_add(*server_snapshots, new_snapshot);

            g_sim_frame_number = snapshot_packet.sequence_number;
            last_snapshot_time = seconds_since_init();

            predict_next_frame = true;
        case;
    }
}

generate_full_snapshot :: (world: *World) -> State_Snapshot {
    result: State_Snapshot;

    // always send over component id list for every entity in the world if it's a full snapshot
    for entity_node_id_table {
        component_types_view := get_component_types(world, it);

        types: [..] u64;
        for component_types_view {
            array_add(*types, it.unique_id);
        }

        entry := table_add(*result.new_nodes, it_index, types);
    }

    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    state := find_or_add(*result.state, networking_ids[it].id);

                    field := array_add(*state.fields);
                    field.field_id = #run component_type_id(%1).unique_id;
                    field.data.only_note = "Sync";

                    byte_buffer_write(*field.data, *datas[it]);
                    field.data.cursor = 0;
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

    return result;
}

generate_prediction_snapshot :: (world: *World) -> State_Snapshot {
    result: State_Snapshot;

    // always send over component id list for every entity in the world if it's a full snapshot
    for entity_node_id_table {
        component_types_view := get_component_types(world, it);

        types: [..] u64;
        for component_types_view {
            array_add(*types, it.unique_id);
        }

        entry := table_add(*result.new_nodes, it_index, types);
    }

    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    if networking_ids[it].id != g_client.local_client_id then continue;

                    state := find_or_add(*result.state, networking_ids[it].id);

                    field := array_add(*state.fields);
                    field.field_id = #run component_type_id(%1).unique_id;
                    field.data.only_note = "Predict";

                    byte_buffer_write(*field.data, *datas[it]);
                    field.data.cursor = 0;
                }
            }
        DONE

        sb: String_Builder;

        for ALL_COMPONENT_TYPES {
            has_sync_fields := false;
            ti := cast(*Type_Info_Struct) it;
            for * member : ti.members {
                if has_note(member, "Sync") && has_note(member, "Predict") {
                    has_sync_fields = true;
                    break;
                }
            }

            if !has_sync_fields then continue;

            sbprint(*sb, INSERT_STRING, it);
        }

        return builder_to_string(*sb);
    }

    return result;
}

interpolate_server_states :: (world: *World, a: State_Snapshot, b: State_Snapshot, alpha: float) {
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

                    a_data: %1;
                    b_data: %1;
                    field_a.data.cursor = 0;
                    byte_buffer_read(*field_a.data, *a_data);
                    field_b.data.cursor = 0;
                    byte_buffer_read(*field_b.data, *b_data);

                    #insert -> string {
                        sb: String_Builder;
                        for member : type_info(%1).members {
                            if has_note(*member, "Interp") {
                                if has_note(*member, "Predict") {
                                    sbprint(*sb, "if networking_ids[it].id != g_client.local_client_id then datas[it].%%1 = lerp(a_data.%%1, b_data.%%1, alpha);", member.name);
                                } else {
                                    sbprint(*sb, "datas[it].%%1 = lerp(a_data.%%1, b_data.%%1, alpha);", member.name);
                                }
                            }
                        }

                        return builder_to_string(*sb);
                    }
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

interpolate_prediction_state :: (world: *World, a: State_Snapshot, b: State_Snapshot, alpha: float) {
    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    if networking_ids[it].id != g_client.local_client_id then continue;

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

                    field_a.data.only_note = "Predict";

                    a_data: %1;
                    b_data: %1;
                    field_a.data.cursor = 0;
                    byte_buffer_read(*field_a.data, *a_data);
                    field_b.data.cursor = 0;
                    byte_buffer_read(*field_b.data, *b_data);

                    #insert -> string {
                        sb: String_Builder;
                        for member : type_info(%1).members {
                            if has_note(*member, "Interp") {
                                sbprint(*sb, "datas[it].%%1 = lerp(a_data.%%1, b_data.%%1, alpha);", member.name);
                            }
                        }

                        return builder_to_string(*sb);
                    }
                }
            }
        DONE

        sb: String_Builder;

        for ALL_COMPONENT_TYPES {
            has_interp_fields := false;
            ti := cast(*Type_Info_Struct) it;
            for * member : ti.members {
                if has_note(member, "Sync") && has_note(member, "Interp") && has_note(member, "Predict") {
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

apply_full_snapshot :: (world: *World, snapshot: State_Snapshot) {
    new_entities: [..] Node_ID;
    new_entities.allocator = temp;

    for snapshot.new_nodes {
        _, found := table_find(*entity_node_id_table, it_index);
        if found then continue;

        ctid_list: [..] Component_Type_ID;
        ctid_list.allocator = temp;
        for it {
            for ctid : ALL_COMPONENT_TYPE_IDS {
                if ctid.unique_id == it {
                    array_add(*ctid_list, ctid);
                }
            }
        }
        entity := spawn_entity(world);

        array_add(*new_entities, it_index);

        add_component(world, entity, Networking_ID, .{it_index});
        for ctid_list {
            add_component(world, entity, it, broadcast=false);
        }
    }

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

    for new_entities {
        ids, success := table_find(*snapshot.new_nodes, it);
        assert(success);

        ctid_list: [..] Component_Type_ID;
        ctid_list.allocator = temp;
        for ids {
            for ctid : ALL_COMPONENT_TYPE_IDS {
                if ctid.unique_id == it {
                    array_add(*ctid_list, ctid);
                }
            }
        }
        entity, found := table_find(*entity_node_id_table, it);
        assert(found);

        for ctid_list {
            // we already broadcasted networking id before, don't do it again
            if it == #run component_type_id(Networking_ID) then continue;

            broadcast_on_component_add(world, entity, it);
        }
    }

    for snapshot.removed_nodes {
        entity, found := table_find(*entity_node_id_table, it);
        assert(found, "A node was removed on the server but we couldn't find the corresponding entity on the client");
        destroy_entity(world, entity);
    }
}

apply_delta_snapshot :: (world: *World, snapshot: State_Snapshot) {
    new_entities: [..] Node_ID;
    new_entities.allocator = temp;

    for snapshot.new_nodes {
        _, found := table_find(*entity_node_id_table, it_index);
        if found then continue;

        ctid_list: [..] Component_Type_ID;
        ctid_list.allocator = temp;
        for it {
            for ctid : ALL_COMPONENT_TYPE_IDS {
                if ctid.unique_id == it {
                    array_add(*ctid_list, ctid);
                }
            }
        }
        entity := spawn_entity(world);

        array_add(*new_entities, it_index);

        add_component(world, entity, Networking_ID, .{it_index});
        for ctid_list {
            add_component(world, entity, it, broadcast=false);
        }
    }

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
                    // field can be null in delta snapshots, it just didn't change
                    if field == null then continue;

                    field.data.only_note = "Sync";

                    // skip applying delta snapshots for data which is locally predicted
                    if networking_ids[it].id == g_client.local_client_id then field.data.skip_note = "Predict";

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

    for new_entities {
        ids, success := table_find(*snapshot.new_nodes, it);
        assert(success);

        ctid_list: [..] Component_Type_ID;
        ctid_list.allocator = temp;
        for ids {
            for ctid : ALL_COMPONENT_TYPE_IDS {
                if ctid.unique_id == it {
                    array_add(*ctid_list, ctid);
                }
            }
        }
        entity, found := table_find(*entity_node_id_table, it);
        assert(found);

        for ctid_list {
            // we already broadcasted networking id before, don't do it again
            if it == #run component_type_id(Networking_ID) then continue;

            broadcast_on_component_add(world, entity, it);
        }
    }

    for snapshot.removed_nodes {
        entity, found := table_find(*entity_node_id_table, it);
        assert(found, "A node was removed on the server but we couldn't find the corresponding entity on the client");
        destroy_entity(world, entity);
    }
}

/**
 * Client -> Server 
 * Sends a packet of data from the client to the server.
 */
networking_send_packet :: (packet_data: *$Type) {
    buffer: ByteBuffer;
    buffer.buff.allocator = temp;
    packet_type := Type.PACKET_TYPE;
    byte_buffer_write(*buffer, *packet_type);
    byte_buffer_write(*buffer, packet_data);

    Sockets.SendMessageToConnection(g_client.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
}

client_init :: (client: *Client) -> bool {
    // Convert the endpoint to a string for debug/logging:
    con_addr : [ IPAddr.MaxStringIPAddrSize ] s8;
    IPAddr.ToString(*client.endpoint, con_addr.data, con_addr.count, /* bWithPort = */ true);
    con_addr_view := view_of_c_string(con_addr.data);

    log("Client is attempting to connect to server at %...", con_addr_view);
    options: [1] ConfigValue;
    ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx client_net_connection_status_changed_callback);
    
    client.connection = Sockets.ConnectByIPAddress(*client.endpoint, options.count, options.data);

    if client.connection == .Invalid {
        log_error("Client failed to connect to server");
        return false;
    }

    array_resize(*networking_bytes_received_stats, NETWORKING_DATA_STATS_WINDOW);
    return true;
}

NETWORKING_DATA_STATS_WINDOW :: 128;
networking_bytes_received_stats: [..] float;

client_update :: (client: *Client) {
    bytes_recv_this_frame : *float = null;
    while !client.should_disconnect {
        incoming_msgs: [8] *NetworkingMessage;
        num_msgs := Sockets.ReceiveMessagesOnConnection(client.connection, incoming_msgs.data, incoming_msgs.count);

        if num_msgs == 0 {
            break;
        }

        assert(num_msgs > 0);
        assert(num_msgs <= incoming_msgs.count);

        for 0..num_msgs - 1 {
            message: *NetworkingMessage = incoming_msgs[it];
            defer NetworkingMessage.Release(message);

            message_view: [] u8;
            message_view.data = message.m_pData;
            message_view.count = message.m_cbSize;

            if message_view.count == 0 then continue;

            if bytes_recv_this_frame == null {
                array_ordered_remove_by_index(*networking_bytes_received_stats, 0);
                bytes_recv_this_frame = array_add(*networking_bytes_received_stats);
            }
            bytes_recv_this_frame.* += cast(float) message.m_cbSize;

            // copy the incoming data into the buffer
            buffer: ByteBuffer;
            buffer.allocator = temp;
            copy_to_buffer(*buffer, message_view);

            buffer.cursor = 0;

            packet_type: PacketType;
            byte_buffer_read(*buffer, *packet_type);

            client_packet_handler(packet_type, *buffer);
        }
    }
    Sockets.RunCallbacks();
}

client_shutdown :: (client: *Client) {
    // enable linger mode to ensure the connection is fully flushed.
    Sockets.CloseConnection(client.connection, 0, null, /* linger= */ true);
}

get_connection_stats :: () -> QuickConnectionStatus {
    stats: QuickConnectionStatus;
    Sockets.GetQuickConnectionStatus(g_client.connection, *stats);
    return stats;
}

client_net_connection_status_changed_callback :: (info: *ConnectionStatusChanged) -> void #c_call {
    new_ctx: Context;
    new_ctx.logger = logger;
    push_context new_ctx {
        handle_client_net_connection_status_changed(*g_client, info);
    }
}

handle_client_net_connection_status_changed :: (client: *Client, info: *ConnectionStatusChanged) {
    // #todo: What to do if client.con is invalid?
    assert(info.m_conn == client.connection || client.connection == .Invalid);

    if info.m_info.m_eState == {
        case .None;
        case .ClosedByPeer; #through;
        case .ProblemDetectedLocally; {
            
            end_debug_message_view := view_of_c_string(info.m_info.m_szEndDebug.data);

            if info.m_eOldState == .Connecting {
                log_error("Unable to connect to server. (%)", end_debug_message_view);
            } 
            else if info.m_info.m_eState == .ProblemDetectedLocally {
                log_error("Lost connection with the host. (%)", end_debug_message_view);
            } 
            else {
                // #todo: check reason for disconnect
                log("Disconnected from the host. (%)", end_debug_message_view);
            }

            Sockets.CloseConnection(client.connection, /* reason */ 0, /* debug message */ null, /* linger */ false);
            client.connection = .Invalid;
            client.should_disconnect = true;
            // #todo: handle disconnection properly, for now just exit if we drop connection
            g_should_exit = true;
        }
        case .Connecting;
        case .Connected;
            log("Connected to server");
        case;
    }
}