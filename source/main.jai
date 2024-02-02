delta_time: float64 = 0.013;

DEFAULT_PORT_NUMBER :: 25566;


/* todo:

- Server is basically just a client, except it has some additional logic at the start (or end) of each frame to propagate changes to clients.

*/

Client :: struct {
    endpoint: IPAddr;
    connection: NetConnection;
}

Server :: struct {
    listen_port: u16 = DEFAULT_PORT_NUMBER;

    listen_socket: ListenSocket;
    poll_group: PollGroup;

    ClientConnection :: struct {
        connection: NetConnection;
        player_id: u64;
    }
    clients: [..] ClientConnection;

    // #todo: is this good enough to just increment every time?
    next_valid_player_id: u64 = 0;
}

g_server: Server;
g_client: Client;

g_should_quit: bool;

main :: () {
    args := get_command_line_arguments();
    defer array_reset(*args);

    if args.count == 1 {
        log("Error: please indicate if running as server or client");
        return;
    }

    if !GameNetworkingSockets.Initialize() {
        log_error("Failed to initialize GNS");
    }

    Utils.SetDebugOutputFunction(.Msg, gns_debug_callback);

    defer GameNetworkingSockets.Finalize();

    if args[1] == "client" {
        client_main();
    } else if args[1] == "server" {
        server_main();
    }
}

server_main :: () {
    if !server_init(*g_server) {
        log_error("Failed to initialize the server!");
        return;
    }

    // Initialize the local client's endpoint to the loopback device
    loopback_ipv4: u32 = 0x7F_00_00_01;
    IPAddr.SetIPv4(*g_client.endpoint, loopback_ipv4, g_server.listen_port);
    if !client_init(*g_client) {
        log_error("Failed to initialize server's local client");
    }

    while !g_should_quit {
        server_update(*g_server);
        client_update(*g_client);
    }
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
    while !g_should_quit {
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

            message_view: string;
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

            log("Received message from client %: \n\t%", sender.player_id, message_view);
        }
    }

    Sockets.RunCallbacks();
}

server_net_connection_status_changed_callback :: (info: *ConnectionStatusChanged) -> void #c_call {
    new_ctx: Context;
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
                    client_disconnection_message = sprint("% connection dropped", client_connection.player_id);
                } else {
                    // check reason if it's "usual" or "unusual".
                    client_disconnection_message = sprint("% disconnected", client_connection.player_id);
                }

                log("Client Connection % %, reason %: %", 
                    connection_desc_view, 
                    client_disconnection_message, 
                    info.m_info.m_eEndReason, 
                    end_debug_view);

                array_unordered_remove_by_index(*server.clients, client_index);

                // #todo: notify all clients of disconnected player
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

            new_player_id := server.next_valid_player_id;
            // validate this player id is not currently in use:
            // #todo: should be non-shipping builds only
            {
                for * server.clients {
                    assert(it.player_id != new_player_id, "player id % is already in use!", new_player_id);
                }
            }
            server.next_valid_player_id += 1;

            new_client: Server.ClientConnection;
            new_client.connection = info.m_conn;
            new_client.player_id = new_player_id;
            // defer the addition to the array so we can do some work to notify existing clients of the new player connection:
            defer array_add(*server.clients, new_client);

            // #todo: notify existing clients of new player
        }
        case .Connected;
        case;
    }
}

client_main :: () {

}

client_init :: (client: *Client) -> bool {

    // Convert the endpoint to a string for debug/logging:
    con_addr : [ IPAddr.MaxStringIPAddrSize ] s8;
    IPAddr.ToString(*client.endpoint, con_addr.data, con_addr.count, /* bWithPort = */ true);
    con_addr_view := view_of_c_string(con_addr.data);

    log("Client is attempting to connect to server at %", con_addr_view);
    options: [1] ConfigValue;
    ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx client_net_connection_status_changed_callback);
    
    client.connection = Sockets.ConnectByIPAddress(*client.endpoint, options.count, options.data);

    if client.connection == .Invalid {
        log_error("Client failed to connect to server");
        return false;
    }

    log("Client connected to server successfully at %", con_addr_view);

    return true;
}

client_update :: (client: *Client) {
    while !g_should_quit {
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

            message_view: string;
            message_view.data = message.m_pData;
            message_view.count = message.m_cbSize;

            if message_view.count == 0 then continue;

            log("received message from server: \n\t%", message_view);
        }
    }

    Sockets.SendStringToConnection(client.connection, "ping", .Reliable, null);

    Sockets.RunCallbacks();
}

client_net_connection_status_changed_callback :: (info: *ConnectionStatusChanged) -> void #c_call {
    new_ctx: Context;
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
        
        print("[gns] %\n", msg_view);
    }
}

simulate :: (delta_time: float64) {

}


// #todo: remove
view_of_c_string :: (c_string : *s8) -> string
{
    ret : string;
    
    if (c_string == null)
    {
        return ret;
    }
    
    ret.data = xx c_string;
    ret.count = c_style_strlen(xx c_string);
    return ret;
}



#import "Basic";
#import "Window_Creation";
#import "Simp";
#import "Input";
#import "Socket";
#import "Thread";
#import "gns";