#scope_export 

Player :: struct {}

LocalPlayer :: struct {}

Networking_ID :: struct {
    id: u64;
}

init_player :: (networking_id: u64, position: Vector2) -> Entity {
    entity := spawn_entity(*g_world);

    add_component(*g_world, entity, Player);
    add_component(*g_world, entity, Name, .{sprint("Player_%", networking_id)});
    add_component(*g_world, entity, Position, .{position});
    add_component(*g_world, entity, Velocity);
    add_component(*g_world, entity, Networking_ID, .{networking_id});

    // if this is a local player:
    if g_client.local_client_id == networking_id {
        add_component(*g_world, entity, LocalPlayer);
    }


    sprite := ifx g_client.local_client_id == networking_id {
        g_local_player_sprite;
    } else {
        g_player_sprite;
    }

    add_component(*g_world, entity, Sprite, .{sprite, .{1.5, 1.5}, 0, 1});


    // Initialize the default base player attributes:
    //player.attribs.base[Attribute.MAX_HEALTH] = 100.;
    //player.attribs.base[Attribute.HEALTH] = 100.;
    //player.attribs.base[Attribute.SPEED] = 10.;

    return entity;
}

update_player_controllers :: (world: *World) {
    for Query(LocalPlayer, Position, Velocity, Networking_ID).{world = world} {
        move_len := length(movement_input);
        // Normalize the input vector to prevent diagonal movement being faster than horizontal
        if move_len > 1 {
            movement_input = unit_vector(movement_input);
            move_len = 1.;
        }

        it.velocity.vel = movement_input * 10;

        movement_input = .{0, 0};

        if move_len > 0 {
            it.position.pos += it.velocity.vel * cast(float32) g_delta_time;

            player_moved: PlayerMove_Packet = ---;
            player_moved.networking_id = it.networking_id.id;
            player_moved.new_position = it.position;

            networking_send_packet(*player_moved);;
        }
    }
} @System

// Update the local player controller, returns true if the player has made an input this frame
update_player_controller :: () -> bool {
    move_len := length(movement_input);
    // Normalize the input vector to prevent diagonal movement being faster than horizontal
    if move_len > 1 {
        movement_input = unit_vector(movement_input);
        move_len = 1.;
    }

    velocity := get_component(*g_world, g_local_player, Velocity);
    velocity.vel = movement_input * 10;

    movement_input = .{0, 0};
    
    return move_len != 0;
}

movement_input: Vector2;

MovePlayerUp :: (key_state: Key_Current_State) {
    movement_input.y += 1;
} @RegisterInputAction

MovePlayerDown :: (key_state: Key_Current_State) {
    movement_input.y -= 1;
} @RegisterInputAction

MovePlayerLeft :: (key_state: Key_Current_State) {
    movement_input.x -= 1;
} @RegisterInputAction

MovePlayerRight :: (key_state: Key_Current_State) {
    movement_input.x += 1;
} @RegisterInputAction

#import "Math";
#import "Input";