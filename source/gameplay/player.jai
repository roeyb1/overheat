#scope_export 

Player :: struct {}

Local_Player :: struct {}

Player_Controller :: struct {
    // Keep track of the velocity added due to user input
    move_velocity: Vector2;
}

Networking_ID :: struct {
    id: u64;
}

init_player :: (networking_id: u64, position: Vector2) -> Entity {
    entity := spawn_entity(*g_world, Player, Velocity);

    add_component(*g_world, entity, Name, .{sprint("Player_%", networking_id)});
    add_component(*g_world, entity, Position, .{position});
    add_component(*g_world, entity, Networking_ID, .{networking_id});
    add_component(*g_world, entity, Move_Speed, .{10});
    add_component(*g_world, entity, Point_Light, .{intensity = 1., color = .{ 255. / 255., 197. / 255., 143./255.}, radius = 10.});

    // if this is a local player:
    if g_client.local_client_id == networking_id {
        add_component(*g_world, entity, Local_Player);
        add_component(*g_world, entity, Player_Controller);
    }


    sprite := ifx g_client.local_client_id == networking_id {
        g_local_player_sprite;
    } else {
        g_player_sprite;
    }

    PLAYER_SIZE :: Vector2.{1.5, 1.5};

    add_component(*g_world, entity, Sprite, .{sprite, PLAYER_SIZE, 0, 10});
    add_component(*g_world, entity, Collider_AABB, .{make_bounds(.{0, 0}, PLAYER_SIZE)});

    return entity;
}

update_player_controllers :: (world: *World) {
    for Query(Local_Player, *Player_Controller, *Velocity, Move_Speed).{world = world} {
        move_len := length(movement_input);
        // Normalize the input vector to prevent diagonal movement being faster than horizontal
        if move_len > 1 {
            movement_input = unit_vector(movement_input);
            move_len = 1.;
        }

        it.player_controller.move_velocity = movement_input * it.move_speed.speed;
        it.velocity.value += it.player_controller.move_velocity;

        movement_input = .{0, 0};
    }
} @System

update_player_positions_on_network :: (world: *World) {
    for Query(Local_Player, Player_Controller, Position, Networking_ID).{world = world} {
        if length(it.player_controller.move_velocity) > 0 {
            player_moved: PlayerMove_Packet = ---;
            player_moved.networking_id = it.networking_id.id;
            player_moved.new_position = it.position;

            networking_send_packet(*player_moved);;
        }
    }
} @System

cleanup_player_controllers :: (world: *World) {
    for Query(*Player_Controller, *Velocity).{world = world} {
        it.velocity.value -= it.player_controller.move_velocity;
        it.player_controller.move_velocity = .{0, 0};
    }
} @System


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
