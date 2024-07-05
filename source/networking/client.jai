
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

            for q : make_iter(*g_world, Networking_ID, Player_Commands) {
                player_commands := query_get(q, Player_Commands);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    if networking_ids[it].id == player_commands_packet.node_id {
                        player_commands[it] = player_commands_packet.commands;
                    }
                }
            }
        case .PLAYER_LEFT;
            player_left: PlayerLeft_Packet;
            byte_buffer_read(buffer, *player_left);

            player_to_kill: Entity;

            for q : make_iter(*g_world, Networking_ID, Player, Name) {
                networking_ids := query_get(q, Networking_ID);
                names := query_get(q, Name);

                for 0..q.count-1 {
                    if networking_ids[it].id == player_left.node_id {
                        destroy_entity(*g_world, q.entities[it]);

                        log("% has left the game.", names[it].name);
                        break;
                    }
                }
            }
        case;
    }
}