#scope_export

INVALID_NODE_ID :: INVALID_ENTITY_INDEX;

Server :: struct {
    listen_port: u16;

    listen_socket: ListenSocket;
    poll_group: PollGroup;

    ClientConnection :: struct {
        connection: NetConnection;
        node_id: Node_ID;
    }
    clients: [..] ClientConnection;

    should_shutdown: bool = false;
}

Node_ID :: s64;

g_server: Server;

on_entity_begin_networking :: (world: *World, entity: Entity) {
    #if SERVER {
        array_add(*added_nodes, entity.raw);
    }

    log("Networking registered for entity {%, %}", entity.index, entity.generation);
} @Event(EcsOnAdd,Networking_ID)

on_entity_end_networking :: (world: *World, entity: Entity) {
    #if SERVER {
        array_add(*removed_nodes, entity.raw);
    }
    log("Networking terminated for entity {%, %}", entity.index, entity.generation);
} @Event(EcsOnRemove,Networking_ID)

PacketType :: enum u8 #specified {
    INVALID                 :: 0;
    CONNECTION_ESTABLISHED  :: 1;
    PLAYER_COMMANDS         :: 2;
    SNAPSHOT                :: 4;
    PLAYER_DELTA            :: 5;
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
    tick: u32;
    commands: Player_Commands;
}

get_ticks_from_time :: (time: float) -> u32 {
    return xx ceil(time * TICK_RATE);
}


networking_init :: () -> bool {
    log("Initializing networking systems...");

    if !GameNetworkingSockets.Initialize() {
        log_error("Failed to initialize GNS");
        return false;
    }

    // Simulate lag
    Utils.SetGlobalConfigValueInt32(ConfigValueLabel.FakePacketLag_Send, 10);
    Utils.SetGlobalConfigValueInt32(ConfigValueLabel.FakePacketLag_Recv, 10);

    Utils.SetDebugOutputFunction(.Msg, gns_debug_callback);

    #if SERVER {
        g_server.listen_port = g_args.port;
        if !server_init(*g_server) {
            log_error("Failed to initialize the server!");
            return false;
        }
        // If we're the server, ensure the local client always has the loopback endpoint - if there is one
        g_args.ip = "127.0.0.1"; 
    }
    #if CLIENT {
        addr_str := tprint("%:%\0", g_args.ip, g_args.port);
        if !IPAddr.ParseString(*g_client.endpoint, xx addr_str.data) {
            log_error("Invalid local ip address %", addr_str);
            return false;
        }

        if !client_init(*g_client) {
            log_error("Failed to initialize client");
            return false;
        }
    }

    log("Initialized networking system with a TPS of % and fixed timestep of % s", TICK_RATE, FIXED_TIMESTEP);
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
#import "Hash";

#if SERVER then #load "server.jai";
#if CLIENT then #load "client.jai";
#load "network_state.jai";
