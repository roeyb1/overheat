server_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .PLAYER_COMMANDS;
            player_commands_packet: Player_Commands_Packet;
            byte_buffer_read(buffer, *player_commands_packet);

            entity, found := table_find(*entity_node_id_table, player_commands_packet.node_id);
            if !found then return;
            // @todo: is this still valid
            //assert(found, "Received a player commands packet for an entity which is not registered in the networking system. How did this happen!?");

            player_commands := get_component(*g_world, entity, Player_Commands);
            assert(player_commands != null);
            << player_commands = player_commands_packet.commands;
        case;
    }
}

get_unique_node_id :: () -> Node_ID {
    g_server.next_valid_networking_id += 1;
    return .{g_server.next_valid_networking_id-1};
}

/**
 * Server -> Clients 
 * Sends a packet of data from the server to all clients.
 */
networking_broadcast :: (packet_data: *$Type) {
    buffer: ByteBuffer;
    buffer.buff.allocator = temp;
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
    buffer.buff.allocator = temp;

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
            buffer.buff.allocator = temp;
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

                player_left := PlayerLeft_Packet.{node_id};
                networking_broadcast(*player_left);
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

            new_networking_id := get_unique_node_id();
            assert(new_networking_id != INVALID_NODE_ID);

            new_client: Server.ClientConnection;
            new_client.connection = info.m_conn;
            new_client.node_id = new_networking_id;
            // defer the addition to the array so we can do some work to notify existing clients of the new player connection:
            defer array_add(*server.clients, new_client);

            init_player(new_networking_id, g_player_start);

            // Indicate to the newly joined player what it's ID is
            {
                conn_established: ConnectionEstablished_Packet;
                conn_established.node_id = new_networking_id;

                nodes_to_treat_as_new: [..] Node_ID;
                nodes_to_treat_as_new.allocator = temp;

                for entity_node_id_table {
                    array_add(*nodes_to_treat_as_new, it_index);
                }
                snapshot := generate_full_snapshot(*g_world, nodes_to_treat_as_new);
                conn_established.initial_snapshot = to_packet(snapshot);

                networking_send_packet(*new_client, *conn_established);
                free(*snapshot);
            }
        }
        case .Connected;
        case;
    }
}
