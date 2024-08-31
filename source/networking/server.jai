snapshot_ring: [TICK_RATE * 2] State_Snapshot;
snapshot_allocators: [TICK_RATE * 2] Pool;

per_player_input_rings: Table(Node_ID, [..] Player_Commands);

push_new_snapshot :: () {
    pool := *snapshot_allocators[snapshot_index(0)];

    if !pool.block_allocator.proc {
        set_allocators(pool);
    } else {
        reset(pool);
    }

    get_snapshot(0).* = generate_full_snapshot(*g_world, .{pool_allocator_proc, pool});
}
snapshot_index :: inline (offset_from_current: s32) -> s64 {
    index := ((cast(s64)g_current_tick) + offset_from_current) % snapshot_ring.count;
    return index;
}

get_snapshot :: (offset_from_current: s32) -> *State_Snapshot {
    return *snapshot_ring[snapshot_index(offset_from_current)];
}

previous_snapshot :: () -> *State_Snapshot {
    return get_snapshot(-1);
}

current_snapshot :: () -> *State_Snapshot {
    return get_snapshot(0);
}

generate_delta_snapshot :: (world: *World, a: State_Snapshot, b: State_Snapshot, allocator: Allocator) -> State_Snapshot {
    result: State_Snapshot;
    result.time = xx seconds_since_init();
    result.tick = g_current_tick;

    result.state.allocator = allocator;
    result.new_nodes.allocator = allocator;
    result.added_fields.allocator = allocator;
    result.removed_fields.allocator = allocator;
    result.removed_nodes.allocator = allocator;

    push_allocator(allocator);
    
    array_append(*result.removed_nodes, removed_nodes);

    for added_nodes {
        entity := entity_from_raw(it);
        assert(ecs_has(world, entity, Networked), "The newly added node (%) doesn't exist in our entity_node_id_table. This is a bug!", it);

        component_types_view := entity_types_get(world, entity);

        types: [..] s64;
        types.allocator = allocator;
        for component_types_view {
            array_add(*types, it);
        }

        entry := table_add(*result.new_nodes, it, types);
    }

    /** Find fields that are in snapshot a but not in b. Any nodes in the expected_missing list will not assert if they are missing from the second state */
    find_missing_fields :: (a: State_Snapshot, b: State_Snapshot, expected_missing: [] Node_ID, allocator: Allocator) -> Table(Node_ID, [..] s64) {
        result: Table(Node_ID, [..] s64);
        result.allocator = allocator;

        // find any removed components in this delta
        for a.state {
            node_id := it_index;
            state_a := it;

            state_b := table_find_pointer(*b.state, node_id);
            if state_b == null {
                assert(array_find(expected_missing, node_id));
                continue;
            }

            for state_a.fields {
                field_id := it_index;
                if !table_contains(*state_b.fields, field_id) {
                    diff_fields, newly_added := find_or_add(*result, node_id);
                    if newly_added then diff_fields.allocator = allocator;
                    
                    array_add(diff_fields, field_id);
                }
            }
        }

        return result;
    }

    result.removed_fields = find_missing_fields(a, b, expected_missing = removed_nodes, allocator);
    result.added_fields = find_missing_fields(b, a, expected_missing = added_nodes, allocator);
    
    // reset the list of nodes that were added/removed during this delta
    added_nodes.count = 0;
    removed_nodes.count = 0;

    INSERT_STRING :: #string DONE 
        for q : iter_make(world, Networked, %1) {
            datas := query_get(q, %1);

            for 0..q.count-1 {
                // if the node is new, it must be sent
                changed := array_find(added_nodes, q.entities[it].raw);

                if !changed {
                    state_a := table_find_pointer(*a.state, q.entities[it].raw);
                    state_b := table_find_pointer(*b.state, q.entities[it].raw);

                    // node must be in state b, otherwise how is it appearing in the query
                    assert(state_b != null);

                    // if the node has no data in state a, we can't delta compress so we must send everything
                    if state_a == null {
                        changed = true;
                    }

                    if !changed {
                        assert(state_a != null && state_b != null);

                        field_a: *ByteBuffer = table_find_pointer(*state_a.fields, cid_get(world, %1));
                        field_b: *ByteBuffer = table_find_pointer(*state_b.fields, cid_get(world, %1));

                        if field_a == null || field_b == null then continue;

                        field_a.only_note = "Sync";
                        field_b.only_note = "Sync";

                        a_data: %1;
                        b_data: %1;
                        field_a.cursor = 0;
                        byte_buffer_read(field_a, *a_data);
                        field_b.cursor = 0;
                        byte_buffer_read(field_b, *b_data);

                        // always sync properties for newly added entities
                        #insert -> string {
                            sb: String_Builder;
                            for member : type_info(%1).members {
                                if has_note(*member, "Sync") {
                                    sbprint(*sb, "changed |= a_data.%%1 != b_data.%%1;\n", member.name);
                                }
                            }

                            return builder_to_string(*sb);
                        }

                    }
                }

                if changed {
                    state, newly_added := find_or_add(*result.state, q.entities[it].raw);
                    if newly_added then state.fields.allocator = allocator;

                    assert(!table_contains(*state.fields, cid_get(world, %1)));
                    field := table_add(*state.fields, cid_get(world, %1), .{});
                    field.only_note = "Sync";
                    set_allocator(field, allocator);

                    byte_buffer_write(field, *datas[it]);
                    field.cursor = 0;
                }
            }
        }
    DONE

    #insert #run for_each_component_type_with_notes(.["Sync"], INSERT_STRING);

    return result;
}

server_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .PLAYER_COMMANDS;
            player_commands_packet: Player_Commands_Packet;
            byte_buffer_read(buffer, *player_commands_packet);

            entity := entity_from_raw(player_commands_packet.node_id);
            assert(ecs_has(*g_world, entity, Networked), "Received a player commands packet for an entity which is not registered in the networking system. How did this happen!?");

            player_commands := ecs_get(*g_world, entity, Player_Commands);
            assert(player_commands != null);
            << player_commands = player_commands_packet.commands;

            input_ring, success := table_find(*per_player_input_rings, player_commands_packet.node_id);
            assert(success);
            input_ring[player_commands_packet.tick % input_ring.count] = <<player_commands;
        case;
    }
}

/**
 * Server -> Clients 
 * Sends a packet of data from the server to all clients.
 */
networking_broadcast :: (packet_data: *$Type) {
    buffer: ByteBuffer;
    set_allocator(*buffer, temp);

    packet_type := Type.PACKET_TYPE;
    byte_buffer_write(*buffer, *packet_type);
    byte_buffer_write(*buffer, packet_data);

    for * g_server.clients {
        Sockets.SendMessageToConnection(it.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
    }
}


/**
 * Server -> Specific client
 */
networking_send_packet :: (client: *Server.ClientConnection, packet_data: *$Type) {
    buffer: ByteBuffer;
    set_allocator(*buffer, temp);

    packet_type := Type.PACKET_TYPE;
    byte_buffer_write(*buffer, *packet_type);
    byte_buffer_write(*buffer, packet_data);

    Sockets.SendMessageToConnection(client.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
}


server_init :: (server: *Server) -> bool {
    log("Starting server...");
    local_addr: IPAddr;
    IPAddr.Clear(*local_addr);

    local_addr.m_port = server.listen_port;

    options: [1] ConfigValue;

    ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx server_net_connection_status_changed_callback);

    server.listen_socket = Sockets.CreateListenSocketIP(*local_addr, options.count, options.data);
    if server.listen_socket == .Invalid {
        log_error("Could not initialize the server listen socket");
        return false;
    }

    server.poll_group = Sockets.CreatePollGroup();
    if server.poll_group == .Invalid {
        Sockets.CloseListenSocket(server.listen_socket);
        log_error("Failed to initialize server poll group");
        return false;
    }

    log("Server is now listening on port %", server.listen_port);
    return true;
}

server_update :: (server: *Server) {
    // process everything in the message queue until there are none left:
    while !server.should_shutdown {
        incoming_msgs: [8] *NetworkingMessage;
        num_msgs := Sockets.ReceiveMessagesOnPollGroup(server.poll_group, incoming_msgs.data, incoming_msgs.count);

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

            sender: *Server.ClientConnection;
            for * server.clients {
                if it.connection == message.m_conn {
                    sender = it;
                    break;
                }
            }
            assert(sender != null);

            // copy the incoming data into the buffer
            buffer: ByteBuffer;
            set_allocator(*buffer, temp);
            array_copy(*buffer.buff, message_view);

            buffer.cursor = 0;

            packet_type: PacketType;
            byte_buffer_read(*buffer, *packet_type);

            server_packet_handler(packet_type, *buffer);
        }
    }

    Sockets.RunCallbacks();
}

server_shutdown :: (server: *Server) {
    log("Closing all connections...");

    // #todo: send a packet to each client signaling them to gracefully shutdown

    for * server.clients {
        Sockets.CloseConnection(it.connection, 0, null, true);
    }
    array_free(server.clients);

    Sockets.CloseListenSocket(server.listen_socket);
    server.listen_socket = .Invalid;
    Sockets.DestroyPollGroup(server.poll_group);
    server.poll_group = .Invalid;
}

server_net_connection_status_changed_callback :: (info: *ConnectionStatusChanged) -> void #c_call {
    new_ctx: Context;
    new_ctx.logger = logger;
    push_context new_ctx {
        handle_server_net_connection_status_changed(*g_server, info);
    }
}

handle_server_net_connection_status_changed :: (server: *Server, info: *ConnectionStatusChanged) {
    if info.m_info.m_eState == {
        case .None;
        case .ClosedByPeer; #through;
        case .ProblemDetectedLocally; {
            // Only consider problems if connection was already established
            if info.m_eOldState == .Connected {
                client_connection: *Server.ClientConnection;
                client_index := 0;
                for * server.clients {
                    if it.connection == info.m_conn {
                        client_connection = it;
                        client_index = it_index;
                        break;
                    }
                }

                assert(client_connection != null);

                client_disconnection_message: string;
                defer free(client_disconnection_message);

                connection_desc_view := view_of_c_string(info.m_info.m_szConnectionDescription.data);
                end_debug_view := view_of_c_string(info.m_info.m_szEndDebug.data);

                if info.m_info.m_eState == .ProblemDetectedLocally {
                    client_disconnection_message = sprint("% connection dropped", client_connection.node_id);
                } else {
                    // check reason if it's "usual" or "unusual".
                    client_disconnection_message = sprint("% disconnected", client_connection.node_id);
                }

                log("Client Connection % %, reason %: %", 
                    connection_desc_view, 
                    client_disconnection_message, 
                    info.m_info.m_eEndReason, 
                    end_debug_view);

                node_id := server.clients[client_index].node_id;

                array_unordered_remove_by_index(*server.clients, client_index);
                input_ring := table_find_pointer(*per_player_input_rings, node_id);
                if input_ring then array_reset(input_ring);

                entity := entity_from_raw(node_id);
                if ecs_has(*g_world, entity, Networked) {
                    entity_destroy(*g_world, entity);
                }
            } else {
                assert(info.m_eOldState == .Connecting);
            }

            Sockets.CloseConnection(info.m_conn, /* reason */ 0, /* debug message */ null, /* linger */ false);
        }
        case .Connecting; {
            {
                for * server.clients {
                    assert(it.connection != info.m_conn, "connection already exists, this should be impossible.");
                }
            }

            log("Connection request received from %", view_of_c_string(info.m_info.m_szConnectionDescription.data));

            if Sockets.AcceptConnection(info.m_conn) != .OK {
                Sockets.CloseConnection(info.m_conn, /* reason */ 0, /* debug message */ null, /* linger */ false);
                log_error("Unable to accept connection");
                return;
            }

            if !Sockets.SetConnectionPollGroup(info.m_conn, server.poll_group) {
                Sockets.CloseConnection(info.m_conn, /* reason */ 0, /* debug message */ null, /* linger */ false);
                log_error("Failed to assign inbound connection to polling group");
                return;
            }

            player := init_player(g_player_start);

            new_client: Server.ClientConnection;
            new_client.connection = info.m_conn;
            new_client.node_id = player.raw;
            // defer the addition to the array so we can do some work to notify existing clients of the new player connection:
            defer array_add(*server.clients, new_client);

            player_input_ring: [..] Player_Commands;
            array_resize(*player_input_ring, TICK_RATE * 2);
            table_add(*per_player_input_rings, player.raw, player_input_ring);

            // Indicate to the newly joined player what it's ID is
            {
                conn_established: ConnectionEstablished_Packet;
                conn_established.node_id = player.raw;

                snapshot := generate_full_snapshot(*g_world, temp);
                conn_established.initial_snapshot.data = to_packet(snapshot);

                networking_send_packet(*new_client, *conn_established);
            }
        }
        case .Connected;
        case;
    }
}

#import "Pool";