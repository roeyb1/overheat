#scope_export

INVALID_NODE_ID :: Node_ID.{0};

Server :: struct {
    listen_port: u16;

    listen_socket: ListenSocket;
    poll_group: PollGroup;

    ClientConnection :: struct {
        connection: NetConnection;
        node_id: Node_ID;
    }
    clients: [..] ClientConnection;

    next_valid_networking_id: u64 = 1;

    should_shutdown: bool = false;
}

g_server: Server;

// @note: node ids are not per-world, therefore we don't need to keep a table per-world.
// two different node ids may point to the same entity id from different worlds
entity_node_id_table: Table(Node_ID, Entity, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

Node_ID :: struct {
    id: u64;
}

node_id_hash :: inline (id: Node_ID) -> u32 {
    return get_hash(id.id);
}

compare_node_id :: inline (a: Node_ID, b: Node_ID) -> bool {
    return a == b;
}

operator== :: inline (a: Node_ID, b: Node_ID) -> bool {
    return a.id == b.id;
}

on_entity_begin_networking :: (world: *World, entity: Entity) {
    networking_id := get_component(world, entity, Networking_ID);
    table_add(*entity_node_id_table, networking_id.id, entity);

    #if SERVER {
        array_add(*added_nodes, networking_id.id);
    }
} @Event(EcsOnAdd,Networking_ID)

on_entity_end_networking :: (world: *World, entity: Entity) {
    networking_id := get_component(world, entity, Networking_ID);
    table_remove(*entity_node_id_table, networking_id.id);

    #if SERVER {
        array_add(*removed_nodes, networking_id.id);
    }
} @Event(EcsOnRemove,Networking_ID)

PacketType :: enum u8 #specified {
    INVALID                 :: 0;
    CONNECTION_ESTABLISHED  :: 1;
    PLAYER_COMMANDS         :: 4;
    SNAPSHOT                :: 6;
}

/** Packet sent from the server to the client assigning it a player id. */
ConnectionEstablished_Packet :: struct {
    PACKET_TYPE :: PacketType.CONNECTION_ESTABLISHED;

    node_id: Node_ID;
    sequence_number: s64;
    initial_snapshot: State_Snapshot_Packet;
}

Player_Commands_Packet :: struct {
    PACKET_TYPE :: PacketType.PLAYER_COMMANDS;

    node_id: Node_ID;
    commands: Player_Commands;
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

    #if SERVER {
        g_server.listen_port = args.port;
        if !server_init(*g_server) {
            log_error("Failed to initialize the server!");
            return false;
        }
        // If we're the server, ensure the local client always has the loopback endpoint - if there is one
        args.ip = "127.0.0.1";
    }
    #if CLIENT {
        addr_str := tprint("%:%\0", args.ip, args.port);
        if !IPAddr.ParseString(*g_client.endpoint, xx addr_str.data) {
            log_error("Invalid local ip address %", addr_str);
            return false;
        }

        if !client_init(*g_client) {
            log_error("Failed to initialize client");
            return false;
        }
    }


    log("Networking systems initialized successfully");
    return true;
}

networking_shutdown :: () {
    #if CLIENT then client_shutdown(*g_client);
    #if SERVER then server_shutdown(*g_server);

    GameNetworkingSockets.Finalize();
}

networking_update :: () {
    #if SERVER then server_update(*g_server);
    #if CLIENT then client_update(*g_client);
}

#scope_file

NetworkingArgs :: struct {
    server := false;
    ip := "127.0.0.1";
    port: u16 = 27015;
}

gns_debug_callback :: (level: DebugOutputLevel, msg: *s8) -> void #c_call {
    new_ctx: Context;
    push_context new_ctx 
    {
        msg_view := view_of_c_string(msg);
        
        //log("[gns] %\n", msg_view);
    }
}

#import "gns";
#import "Command_Line";

#if SERVER then #load "server.jai";
#if CLIENT then #load "client.jai";
#load "network_state.jai";
