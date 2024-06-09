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
    entity := spawn_entity(*g_world, Player, Velocity, Name, Position, Networking_ID, Move_Speed, Point_Light, Anim_State_Component, Animation, Direction);

    << get_component(*g_world, entity, Name) = .{sprint("Player_%", networking_id)};
    << get_component(*g_world, entity, Position) = .{position};
    << get_component(*g_world, entity, Networking_ID) = .{networking_id};
    << get_component(*g_world, entity, Move_Speed) =  .{6};
    << get_component(*g_world, entity, Point_Light) = .{intensity = 1., color = .{ 255. / 255., 197. / 255., 143./255.}, radius = 10.};
    << get_component(*g_world, entity, Animation) = .{CHARACTER_IDLE_DEFINITION,0,CHARACTER_IDLE_DEFINITION.frame_duration, false};


    // if this is a local player:
    if g_client.local_client_id == networking_id {
        add_component(*g_world, entity, Local_Player);
        add_component(*g_world, entity, Player_Controller);
    }


    sprite := ifx g_client.local_client_id == networking_id {
        load_spritesheet("assets/players/player_character1.png",48, 0, 0,23,4);
    } else {
        load_spritesheet("assets/players/player_character2.png", 48, 0, 0,23,4);
    }

    PLAYER_SIZE :: Vector2.{2.3, 2.3};
    PLAYER_COLLIDER_SIZE :: Vector2.{1., 1.};

    add_component(*g_world, entity, Sprite, .{sprite, PLAYER_SIZE, 0, 4, 0});
    add_component(*g_world, entity, Collider_AABB, .{aabb = make_aabb(.{0, 0}, PLAYER_COLLIDER_SIZE)});
    add_component(*g_world, entity, Collision_Invoker);

    return entity;
}

update_player_controllers :: (world: *World) {
    for query : Query(Local_Player, *Player_Controller, *Velocity, Move_Speed, Anim_State_Component).{world = world} {
        player_controllers := query.player_controller;
        velocities := query.velocity;
        move_speeds := query.move_speed;
        anim_states := query.anim_state_component;

        for 0..query.count-1 {
            player_controllers[it].move_velocity = .{0, 0};
            move_len := length(movement_input);
            // Normalize the input vector to prevent diagonal movement being faster than horizontal
            if move_len > 1 {
                movement_input = unit_vector(movement_input);
                move_len = 1.;
            }

            // @todo: is there a better way to block movement while attacking?
            current_anim_state := cast(Player_Anim_State) anim_states[it].state;
            if current_anim_state != .ATTACK && current_anim_state != .ATTACK_WIND_UP {
                player_controllers[it].move_velocity = movement_input * move_speeds[it].speed;
                velocities[it].value += player_controllers[it].move_velocity;
            }

            movement_input = .{0, 0};
        }
    }
} @System

update_player_positions_on_network :: (world: *World) {
    for query : Query(Local_Player, Player_Controller, Position, Networking_ID).{world = world} {
        player_controllers := query.player_controller;
        positions := query.position;
        networking_ids := query.networking_id;

        for 0..query.count-1 {
            if length_squared(player_controllers[it].move_velocity) > 0 {
                player_moved: PlayerMove_Packet = ---;
                player_moved.networking_id = networking_ids[it].id;
                player_moved.new_position = positions[it];

                networking_send_packet(*player_moved);;
            }
        }
    }
} @System

cleanup_player_controllers :: (world: *World) {
    for query : Query(*Player_Controller, *Velocity).{world = world} {
        velocities := query.velocity;
        player_controllers := query.player_controller;

        for 0..query.count-1 {
            velocities[it].value -= player_controllers[it].move_velocity;
        }
    }
} @System


trigger_player_attack :: (world: *World) {
    log("Player attacked!");
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
