#scope_export

Client :: struct {
    endpoint: IPAddr;
    connection: NetConnection;

    should_disconnect: bool = false;

    local_client_id: u64;
}

Server :: struct {
    listen_port: u16;

    listen_socket: ListenSocket;
    poll_group: PollGroup;

    ClientConnection :: struct {
        connection: NetConnection;
        networking_id: u64;
    }
    clients: [..] ClientConnection;

    next_valid_networking_id: u64 = 0;

    should_shutdown: bool = false;
}

g_server: Server;
g_client: Client;

PacketType :: enum u8 #specified {
    INVALID                 :: 0;
    CONNECTION_ESTABLISHED  :: 1;
    PLAYER_MOVE             :: 2;
    PLAYER_JOINED           :: 3;
    PLAYER_LEFT             :: 4;
}

/** Packet sent from the server to the client assigning it a player id. */
ConnectionEstablished_Packet :: struct {
    PACKET_TYPE :: PacketType.CONNECTION_ESTABLISHED;

    networking_id: u64;

    // #hack: using the player joined packet to avoid adding a new struct
    existing_players: [..] PlayerJoined_Packet;
}

/** Packet sent from the server to all clients indicating a new player has joined the game. */
PlayerJoined_Packet :: struct {
    PACKET_TYPE :: PacketType.PLAYER_JOINED;

    networking_id: u64;
    position: Vector2;
}

PlayerLeft_Packet :: struct {
    PACKET_TYPE :: PacketType.PLAYER_LEFT;

    networking_id: u64;
}

PlayerMove_Packet :: struct {
    PACKET_TYPE :: PacketType.PLAYER_MOVE;

    networking_id: u64;
    new_position: Vector2;
}

networking_init :: () -> bool {
    log("Initializing networking systems...");

    if !GameNetworkingSockets.Initialize() {
        log_error("Failed to initialize GNS");
        return false;
    }

    /*
    Simulate lag
    Utils.SetGlobalConfigValueInt32(ConfigValueLabel.FakePacketLag_Send, 30);
    Utils.SetGlobalConfigValueInt32(ConfigValueLabel.FakePacketLag_Recv, 30);
    */

    Utils.SetDebugOutputFunction(.Msg, gns_debug_callback);

    _, args, is_set_args := parse_arguments(NetworkingArgs);

    g_is_server = args.server;

    if is_server() {
        g_server.listen_port = args.port;

        if !server_init(*g_server) {
            log_error("Failed to initialize the server!");
            return false;
        }

        // If we're the server, ensure the local client always has the loopback endpoint.
        args.ip = "127.0.0.1";
    }

    addr_str := tprint("%:%\0", args.ip, args.port);
    if !IPAddr.ParseString(*g_client.endpoint, xx addr_str.data) {
        log_error("Invalid local ip address %", addr_str);
        return false;
    }

    if !client_init(*g_client) {
        log_error("Failed to initialize client");
        return false;
    }


    log("Rendering systems initialized successfully");
    return true;
}

networking_shutdown :: () {
    client_shutdown(*g_client);
    if is_server() {
        server_shutdown(*g_server);
    }

    GameNetworkingSockets.Finalize();
}

networking_update :: () {
    if is_server() {
        server_update(*g_server);
    }
    client_update(*g_client);
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

/**
 * Server -> Clients 
 * Sends a packet of data from the server to all clients.
 */
networking_broadcast :: (packet_data: *$Type) {
    if is_server() {
        buffer: ByteBuffer;
        buffer.buff.allocator = temp;
        packet_type := Type.PACKET_TYPE;

        byte_buffer_write(*buffer, *packet_type);
        byte_buffer_write(*buffer, packet_data);

        for * g_server.clients {
            Sockets.SendMessageToConnection(it.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
        }
    }
}



/**
 * Server -> Specific client
 */
networking_send_packet :: (client: *Server.ClientConnection, packet_data: *$Type) {
    if is_server() {
        buffer: ByteBuffer;
        buffer.buff.allocator = temp;

        packet_type := Type.PACKET_TYPE;
        byte_buffer_write(*buffer, *packet_type);
        byte_buffer_write(*buffer, packet_data);

        Sockets.SendMessageToConnection(client.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
    }
}


is_server :: inline () -> bool {
    return g_is_server;
}

#scope_file

g_is_server: bool = false;

NetworkingArgs :: struct {
    server := false;
    ip := "127.0.0.1";
    port: u16 = 27015;
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

    // Set the allocator for the packet queue to the global temp allocator. This will ensure it gets cleared every frame:
    return true;
}

client_update :: (client: *Client) {
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
                    client_disconnection_message = sprint("% connection dropped", client_connection.networking_id);
                } else {
                    // check reason if it's "usual" or "unusual".
                    client_disconnection_message = sprint("% disconnected", client_connection.networking_id);
                }

                log("Client Connection % %, reason %: %", 
                    connection_desc_view, 
                    client_disconnection_message, 
                    info.m_info.m_eEndReason, 
                    end_debug_view);

                networking_id := server.clients[client_index].networking_id;

                array_unordered_remove_by_index(*server.clients, client_index);

                
                player_left := PlayerLeft_Packet.{networking_id};
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

            new_networking_id := server.next_valid_networking_id;

            // validate this player id is not currently in use:
            {
                for * server.clients {
                    assert(it.networking_id != new_networking_id, "player id % is already in use!", new_networking_id);
                }
            }
            server.next_valid_networking_id += 1;

            new_client: Server.ClientConnection;
            new_client.connection = info.m_conn;
            new_client.networking_id = new_networking_id;
            // defer the addition to the array so we can do some work to notify existing clients of the new player connection:
            defer array_add(*server.clients, new_client);

            // Indicate to the newly joined player what it's ID is and who is in the world:
            {
                conn_established: ConnectionEstablished_Packet;
                conn_established.networking_id = new_networking_id;

                for :Player_It g_world {
                    player_data := array_add(*conn_established.existing_players);
                    player_data.networking_id = it.networking_id;
                    player_data.position = it.position;
                }

                networking_send_packet(*new_client, *conn_established);
            }

            // Notify all clients about the newly joined player:
            {
                player_joined: PlayerJoined_Packet = ---;
                player_joined.networking_id = new_networking_id;
                player_joined.position = .{0, 0};
                networking_broadcast(*player_joined);
            }

        }
        case .Connected;
        case;
    }
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

gns_debug_callback :: (level: DebugOutputLevel, msg: *s8) -> void #c_call {
    new_ctx: Context;
    push_context new_ctx 
    {
        msg_view := view_of_c_string(msg);
        
        //log("[gns] %\n", msg_view);
    }
}

view_of_c_string :: (c_string : *s8) -> string {
    ret : string;
    
    if (c_string == null)
    {
        return ret;
    }
    
    ret.data = xx c_string;
    ret.count = c_style_strlen(xx c_string);
    return ret;
}

// #todo: refactor this handler into some functions that can exist independently and are dispatched via generated code
client_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .CONNECTION_ESTABLISHED;
            conn_established: ConnectionEstablished_Packet;
            conn_established.existing_players.allocator = temp;

            byte_buffer_read(buffer, *conn_established);

            g_client.local_client_id = conn_established.networking_id;
            log("Local player was assigned id %", conn_established.networking_id);

            g_local_player = init_local_player(conn_established.networking_id);

            for player_data : conn_established.existing_players {
                player := init_remote_player(player_data.networking_id,player_data.position);
                log("Existing player initialized %", player.networking_id);
            }
        case .PLAYER_JOINED;
            player_joined: PlayerJoined_Packet;
            byte_buffer_read(buffer, *player_joined);
            
            log("New player has joined the game: %", player_joined.networking_id);

            player := make_entity(*g_world, Player, tprint("Player_%", player_joined.networking_id));
            player.position = player_joined.position;
            player.networking_id = player_joined.networking_id;
            player.sprite = Sprite.{g_player_sprite, .{1.5, 1.5}, 0, 1};

        case .PLAYER_MOVE;
            player_move: PlayerMove_Packet;
            byte_buffer_read(buffer, *player_move);

            assert(player_move.networking_id != g_local_player.networking_id, 
                "The player should never receive a move packet for itself. We are allowing clients to be authoritative over their positions so this shouldn't happen.");

            for :Player_It g_world {
                if it.networking_id == player_move.networking_id {
                    it.position = player_move.new_position;
                }
            }
        case .PLAYER_LEFT;
            player_left: PlayerLeft_Packet;
            byte_buffer_read(buffer, *player_left);

            player_to_kill: *Player = null;
            for :Player_It g_world {
                if it.networking_id == player_left.networking_id {
                    player_to_kill = it;
                    break;
                }
            }

            assert(player_to_kill != null);
            destroy_entity(*g_world, player_to_kill);
        case;
    }
}

server_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .PLAYER_MOVE;
            player_move: PlayerMove_Packet;
            byte_buffer_read(buffer, *player_move);
            // #todo: we can do something to validate the correctness of the movement, but for now just forward it to all clients:
            for * g_server.clients {
                // let the client be authoritative about its movement, don't send movement packets back to the client they came from
                if it.networking_id != player_move.networking_id {
                    Sockets.SendMessageToConnection(it.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
                }
            }
        case;
    }
}

#import "gns";
#import "Command_Line";

#load "byte_buffer.jai";