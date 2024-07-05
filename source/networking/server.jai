server_packet_handler :: (packet_type: PacketType, buffer: *ByteBuffer) {
    if packet_type == {
        case .PLAYER_COMMANDS;
            player_commands_packet: Player_Commands_Packet;
            byte_buffer_read(buffer, *player_commands_packet);

            entity, found := table_find(*entity_node_id_table, player_commands_packet.node_id);
            assert(found, "Received a player commands packet for an entity which is not registered in the networking system. How did this happen!?");

            player_commands := get_component(*g_world, entity, Player_Commands);
            assert(player_commands != null);
            << player_commands = player_commands_packet.commands;
        case;
    }
}
