server_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .PLAYER_COMMANDS;
            player_commands_packet: Player_Commands_Packet;
            byte_buffer_read(buffer, *player_commands_packet);
            for * g_server.clients {
                // let the client be authoritative about its movement, don't send movement packets back to the client they came from
                if it.node_id != player_commands_packet.node_id {
                    Sockets.SendMessageToConnection(it.connection, buffer.buff.data, xx buffer.buff.count, .Reliable, null);
                }
            }
        case;
    }
}

server_post_simulate :: () {
    assert(is_server());

    snapshot := generate_full_snapshot(*g_world);

    // @todo store the snapshot
}