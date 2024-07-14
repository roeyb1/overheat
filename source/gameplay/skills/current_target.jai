Current_Target :: struct @Component {
    value: Vector2;

    main_attack: bool;
    secondary_attack: bool;
}

#if CLIENT {
update_player_cursor_position :: (world: *World, player: Entity) {

    cursor_position := get_mouse_worldspace();
    current_target := get_component(world, player, Current_Target);
    networking_id := get_component(world, player, Networking_ID);


    if (current_target && networking_id) {
        player_targeting_location_packet: Player_targeting_Location_Packet;
        player_targeting_location_packet.node_id = networking_id.id;
        player_targeting_location_packet.location = .{cursor_position,true,true};
        player_targeting_location_packet.tick = g_current_tick;
        networking_send_packet(*player_targeting_location_packet);
    }

    current_target.value = cursor_position;
} 

get_mouse_worldspace :: () -> Vector2 {
    viewport := get_singleton(*g_world, Game_Viewport);
    camera := get_component(*g_world, viewport.main_camera, Camera);
    cam_pos := get_component(*g_world, viewport.main_camera, Position);
    s_x, s_y := get_mouse_cursor_pos();
    v := viewspace_to_worldspace(camera.projection, cam_pos, .{cast(float)s_x, cast(float)s_y});
    return v;
}
}
