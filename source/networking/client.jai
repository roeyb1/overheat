Client :: struct {
    endpoint: IPAddr;
    connection: NetConnection;

    should_disconnect: bool = false;

    local_client_id: Node_ID = INVALID_NODE_ID;
}

g_client: Client;

input_ring: [TICK_RATE * 2] Player_Commands;

snapshot_ring: [TICK_RATE * 2] State_Snapshot; // currently only stores the last 2 server snapshots for interp
snapshot_allocators: [TICK_RATE * 2] Pool;
last_received_snapshot_tick: s64 = -1;

prediction_ring: [TICK_RATE * 2] State_Snapshot;
prediction_allocators: [TICK_RATE * 2] Pool;

last_snapshot_time: float64;
last_prediction_time: float64;

last_known_server_time: float;
last_received_server_time: float;

smooth_server_time: float;
ping: float;
server_interp_time: float;

g_enable_prediction: bool = true;

push_new_server_snapshot :: (tick: u32) {
    pool := *snapshot_allocators[tick % snapshot_allocators.count];

    if !pool.block_allocator.proc {
        set_allocators(pool);
    } else {
        reset(pool);
    }

    snapshot_ring[tick % snapshot_ring.count] = generate_full_snapshot(*g_world, .{pool_allocator_proc, pool});
}

previous_snapshot :: () -> *State_Snapshot {
    assert(last_received_snapshot_tick != -1);
    return *snapshot_ring[(last_received_snapshot_tick - 1) % snapshot_ring.count];
}

current_snapshot :: () -> *State_Snapshot {
    assert(last_received_snapshot_tick != -1);
    return *snapshot_ring[last_received_snapshot_tick % snapshot_ring.count];
}

push_new_prediction :: () {
    assert(g_enable_prediction);

    pool := *prediction_allocators[prediction_index(0)];

    if !pool.block_allocator.proc {
        set_allocators(pool);
    } else {
        reset(pool);
    }

    get_prediction(0).* = generate_prediction_snapshot(*g_world, .{pool_allocator_proc, pool});
}

prediction_index :: inline (offset_from_current: s32) -> s64 {
    index := ((cast(s64)g_current_tick) + offset_from_current) % prediction_ring.count;
    return index;
}

get_prediction :: (offset_from_current: s32) -> *State_Snapshot {
    assert(g_enable_prediction);
    return *prediction_ring[prediction_index(offset_from_current)];
}

previous_prediction :: () -> *State_Snapshot {
    assert(g_enable_prediction);
    return get_prediction(-1);
}

current_prediction :: () -> *State_Snapshot {
    assert(g_enable_prediction);
    return get_prediction(0);
}

is_prediction_valid :: (offset_from_current: s32) -> bool {
    if !g_enable_prediction return false;

    pred := get_prediction(offset_from_current);

    if pred.tick == 0 || (cast(s64) pred.tick) != (cast(s64)g_current_tick + offset_from_current) then return false;

    return true;
}

client_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .CONNECTION_ESTABLISHED;
            conn_established: ConnectionEstablished_Packet;

            byte_buffer_read(buffer, *conn_established);

            assert(conn_established.node_id != INVALID_NODE_ID);

            g_client.local_client_id = conn_established.node_id;

            last_known_server_time = conn_established.initial_snapshot.time;
            last_received_server_time = xx seconds_since_init();
            g_current_tick = get_ticks_from_time(last_known_server_time);

            log("Local player was assigned id %", conn_established.node_id);

            snapshot := from_packet(conn_established.initial_snapshot.data, temp);
            last_snapshot_time = seconds_since_init();

            apply_full_snapshot(*g_world, snapshot);

        case .PLAYER_COMMANDS;
            player_commands_packet: Player_Commands_Packet;
            byte_buffer_read(buffer, *player_commands_packet);

            assert(player_commands_packet.node_id != g_client.local_client_id, 
                "The player should never receive a move packet for itself. We are allowing clients to be authoritative over their positions so this shouldn't happen.");

            entity := entity_from_raw(player_commands_packet.node_id);
            assert(ecs_has(*g_world, entity, Networked), "Received a player commands packet for an entity which is not registered in the networking system. How did this happen!?");

            player_commands := ecs_get(*g_world, entity, Player_Commands);
            assert(player_commands != null);
            << player_commands = player_commands_packet.commands;
        case .PLAYER_DELTA;
            snapshot_packet: Player_State_Snapshot_Packet;
            byte_buffer_read(buffer, *snapshot_packet);

            if !(snapshot_packet.input == input_ring[snapshot_packet.tick % input_ring.count]) {
                log("Frame % mispredict! Server/Client input mismatch (s) % (c) %", snapshot_packet.tick, snapshot_packet.input, input_ring[snapshot_packet.tick % input_ring.count]);
            }

            last_known_server_time = snapshot_packet.time;
            last_received_server_time = xx seconds_since_init();

            // when we receive a new delta from the server:
            // - apply the delta to the world state
            // - build a new full snapshot  <--- @todo: this part is really slow and stupid, we should be able to apply the delta on top of the state
            // - store that snapshot for interpolation purposes

            delta := from_packet(snapshot_packet.data, temp);
            apply_delta_snapshot(*g_world, delta);

            last_received_snapshot_tick = snapshot_packet.tick;
            push_new_server_snapshot(snapshot_packet.tick);
        case;
    }
}

generate_prediction_snapshot :: (world: *World, allocator: Allocator) -> State_Snapshot {
    assert(g_enable_prediction, "We're trying to apply prediction when prediction is disabled");

    result: State_Snapshot;
    result.tick = g_current_tick;
    result.time = xx seconds_since_init();

    result.state.allocator = allocator;
    result.new_nodes.allocator = allocator;
    result.added_fields.allocator = allocator;
    result.removed_fields.allocator = allocator;
    result.removed_nodes.allocator = allocator;

    for q : iter_make(world, Networked) {
        types: [..] s64;
        types.allocator = allocator;
        array_copy(*types, q.current_archetype.type_ids);

        for 0..q.count-1 {
            entry := table_add(*result.new_nodes, q.entities[it].raw, types);
        }
    }

    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : iter_make(world, Networked, %1) {
                datas := query_get(q, %1);

                for 0..q.count-1 {
                    if q.entities[it].raw != g_client.local_client_id then continue;

                    state, newly_added := find_or_add(*result.state, q.entities[it].raw);
                    if newly_added then state.fields.allocator = allocator;

                    assert(!table_contains(*state.fields, cid_get(world, %1)));
                    field := table_add(*state.fields, cid_get(world, %1), .{});
                    field.only_note = "Predict";
                    set_allocator(field, allocator);

                    byte_buffer_write(field, *datas[it]);
                    field.cursor = 0;
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
    assert(a.tick != 0 && b.tick != 0);
    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : iter_make(world, Networked, %1) {
                datas := query_get(q, %1);

                for 0..q.count-1 {
                    state_a, success_a := table_find(*a.state, q.entities[it].raw);
                    state_b, success_b := table_find(*b.state, q.entities[it].raw);

                    if !success_a || !success_b then continue;

                    field_a: *ByteBuffer = table_find_pointer(*state_a.fields, cid_get(world, %1));
                    field_b: *ByteBuffer = table_find_pointer(*state_b.fields, cid_get(world, %1));

                    if field_a == null || field_b == null then continue;

                    field_a.only_note = "Interp";

                    a_data: %1;
                    b_data: %1;
                    field_a.cursor = 0;
                    byte_buffer_read(field_a, *a_data);
                    field_b.cursor = 0;
                    byte_buffer_read(field_b, *b_data);

                    #insert -> string {
                        sb: String_Builder;
                        for member : type_info(%1).members {
                            if has_note(*member, "Interp") {
                                if has_note(*member, "Predict") {
                                    sbprint(*sb, "if (!g_enable_prediction || q.entities[it].raw != g_client.local_client_id) then datas[it].%%1 = lerp(a_data.%%1, b_data.%%1, alpha);", member.name);
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
    assert(g_enable_prediction);
    assert(a.tick != 0 && b.tick != 0);
    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : iter_make(world, Networked, %1) {
                datas := query_get(q, %1);

                for 0..q.count-1 {
                    if q.entities[it].raw != g_client.local_client_id then continue;

                    state_a, success_a := table_find(*a.state, q.entities[it].raw);
                    state_b, success_b := table_find(*b.state, q.entities[it].raw);

                    if !success_a || !success_b then continue;

                    field_a: *ByteBuffer = table_find_pointer(*state_a.fields, cid_get(world, %1));

                    field_b: *ByteBuffer = table_find_pointer(*state_b.fields, cid_get(world, %1));

                    if field_a == null || field_b == null then continue;

                    field_a.only_note = "Predict";
                    field_b.only_note = "Predict";

                    a_data: %1;
                    b_data: %1;
                    field_a.cursor = 0;
                    byte_buffer_read(field_a, *a_data);
                    field_b.cursor = 0;
                    byte_buffer_read(field_b, *b_data);

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

spawn_new_entities_from_snapshot :: (world: *World, snapshot: State_Snapshot) #expand {
    new_nodes: [..] Node_ID;
    new_nodes.allocator = temp;

    for snapshot.new_nodes {
        {
            entity := entity_from_raw(it_index);
            if entity_is_valid(world, entity) && ecs_has(world, entity, Networked) then continue;
        }
        array_add(*new_nodes, it_index);

        cid_list: [..] s64 = it;

        entity := entity_make(*world.stage, entity_from_raw(it_index), .[]);

        ecs_add(world, entity, Networked);

        log("Spawning new networked entity: {%, %}", entity.index, entity.generation);

        for cid_list {
            ecs_add(world, entity, it, broadcast=false);
        }
    }

    `defer {
        for node_id : new_nodes {
            fields, success := table_find(*snapshot.new_nodes, node_id);
            assert(success);

            cid_list: [..] s64 = fields;

            entity := entity_from_raw(node_id);
            assert(ecs_has(world, entity, Networked));

            for cid_list {
                // we already broadcasted networking id before, don't do it again
                if it == cid_get(world, Networked) then continue;

                event_broadcast(world, cid_pair(world, EcsOnAdd, it), entity);
            }
        }
    }
}

destroy_entities_removed_in_snapshot :: (world: *World, snapshot: State_Snapshot) {
    for snapshot.removed_nodes {
        entity := entity_from_raw(it);
        if ecs_has(world, entity, Networked) {
            entity_destroy(world, entity);
        }
    }
}

apply_full_snapshot :: (world: *World, snapshot: State_Snapshot) {
    destroy_entities_removed_in_snapshot(world, snapshot);

    spawn_new_entities_from_snapshot(world, snapshot);

    INSERT_STRING :: #string DONE 
        for q : iter_make(world, Networked, %1) {
            datas := query_get(q, %1);

            for 0..q.count-1 {
                state, success := table_find(*snapshot.state, q.entities[it].raw);
                // it's fine if we don't have an entry for the entity, since it may not exist on the client yet
                assert(success);

                field: *ByteBuffer = table_find_pointer(*state.fields, cid_get(world, %1));
                assert(field != null);

                field.only_note = "Sync";
                field.cursor = 0;

                byte_buffer_read(field, *datas[it]);
            }
        }
    DONE

    #insert #run for_each_component_type_with_notes(.["Sync"], INSERT_STRING);
}

apply_delta_snapshot :: (world: *World, snapshot: State_Snapshot) {
    new_entities: [..] Node_ID;
    new_entities.allocator = temp;

    destroy_entities_removed_in_snapshot(world, snapshot);

    spawn_new_entities_from_snapshot(world, snapshot);

    for snapshot.added_fields {
        entity := entity_from_raw(it_index);
        assert(ecs_has(world, entity, Networked));

        cid_list: [..] s64 = it;

        for cid_list {
            ecs_add(world, entity, it, broadcast=false);
        }
    }

    for snapshot.removed_fields {
        entity := entity_from_raw(it_index);
        assert(ecs_has(world, entity, Networked));

        for field_id : it {
            for q : iter_make(world, EcsComponent) {
                for cent : q.entities {
                    if cid_from_entity(cent) == field_id then ecs_remove(world, entity, field_id);
                }
            }
        }
    }

    INSERT_STRING :: #string DONE 
        for q : iter_make(world, Networked, %1) {
            datas := query_get(q, %1);

            for 0..q.count-1 {
                state, success := table_find(*snapshot.state, q.entities[it].raw);
                // it's fine if we don't have an entry for the entity, since it may not exist on the client yet
                // @todo: this should really be an assert tho
                if !success then continue;

                field: *ByteBuffer = table_find_pointer(*state.fields, cid_get(world, %1));

                // field can be null in delta snapshots, it just didn't change
                if field == null then continue;

                field.only_note = "Sync";

                // skip applying delta snapshots for data which is locally predicted
                if g_enable_prediction && q.entities[it].raw == g_client.local_client_id then field.skip_note = "Predict";

                field.cursor = 0;

                byte_buffer_read(field, *datas[it]);
            }
        }
    DONE

    #insert #run for_each_component_type_with_notes(.["Sync"], INSERT_STRING);

    for snapshot.added_fields {
        entity := entity_from_raw(it_index);
        assert(ecs_has(world, entity, Networked));

        cid_list: [..] s64 = it;

        for cid_list {
            event_broadcast(world, cid_pair(world, EcsOnAdd, it), entity);
        }
    }
}

apply_prediction_state :: (world: *World, snapshot: State_Snapshot) {
    assert(g_enable_prediction);
    assert(snapshot.tick != 0);

    INSERT_STRING :: #string DONE 
        for q : iter_make(world, Networked, %1) {
            datas := query_get(q, %1);

            for 0..q.count-1 {
                if q.entities[it].raw != g_client.local_client_id then continue;

                state, success := table_find(*snapshot.state, q.entities[it].raw);
                assert(success);

                field: *ByteBuffer = table_find_pointer(*state.fields, cid_get(world, %1));

                assert(field != null);

                field.only_note = "Predict";

                field.cursor = 0;

                byte_buffer_read(field, *datas[it]);
            }
        }
    DONE
    
    #insert #run for_each_component_type_with_notes(.["Sync", "Interp", "Predict"], INSERT_STRING);
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

    // estimate what the server time _will be_ when it processes a packet if we send it now:
    ping = get_connection_stats().m_nPing / 1000.;
    estimated_server_time := last_known_server_time + (xx seconds_since_init() - last_received_server_time) + 2 * ping;

    // smoothly maintain the server time between +- 0.1s of the actual server time
    #assert(FIXED_TIMESTEP < 0.1);
    if estimated_server_time - smooth_server_time > 0.1 {
        smooth_server_time = estimated_server_time;
        log("Estimated server time fell too far behind, snapping forward.");
    } else if estimated_server_time > smooth_server_time {
        smooth_server_time += g_delta_time * 1.03;
    } else if estimated_server_time < smooth_server_time {
        smooth_server_time += g_delta_time * 0.97;
    }

    //server_interp_time = last_known_server_time + (xx seconds_since_init() - last_received_server_time);
    server_interp_time = smooth_server_time - 2 * ping;

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
            set_allocator(*buffer, temp);
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
    init_context_logger(*new_ctx);
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

#import "Pool";