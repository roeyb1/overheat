#scope_export 

Player :: struct {} @Component

Local_Player :: struct {} @Component

Player_Controller :: struct {
    // Keep track of the velocity added due to user input
    velocity_from_input: Vector2;
} @Component

Networking_ID :: struct {
    id: u64;
} @Component

Player_Commands :: struct {
    move_vector: Vector2;

    main_attack: bool;
    secondary_attack: bool;
} @Component

init_player :: (networking_id: u64, position: Vector2) -> Entity {
    entity := spawn_entity(*g_world,
        Player,
        Velocity,
        Name,
        Player_Commands,
        Position,
        Interp_Position,
        Networking_ID,
        Move_Speed,
        Point_Light,
        Anim_State_Component,
        Animation,
        Direction,
        Player_Controller);

    << get_component(*g_world, entity, Name) = .{sprint("Player_%", networking_id)};
    << get_component(*g_world, entity, Position) = .{position};
    << get_component(*g_world, entity, Interp_Position) = .{position, position};
    << get_component(*g_world, entity, Networking_ID) = .{networking_id};
    << get_component(*g_world, entity, Move_Speed) =  .{6};
    << get_component(*g_world, entity, Point_Light) = .{intensity = 1., color = .{ 255. / 255., 197. / 255., 143./255.}, radius = 10.};
    << get_component(*g_world, entity, Animation) = .{CHARACTER_IDLE_DEFINITION,0,CHARACTER_IDLE_DEFINITION.frame_duration, false};


    // if this is a local player:
    if g_client.local_client_id == networking_id {
        add_component(*g_world, entity, Local_Player);
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

update_local_player_commands_from_input :: (world: *World) {
    for query : Query(Local_Player, *Player_Commands).{world = world} {
        player_commands := query.player_commands;
        for 0..query.count-1 {
            // reset previous frame's command state:
            memset(*player_commands[it], 0, size_of(Player_Commands));

            if is_button_down(*g_input_states, .MOVE_UP) {
                player_commands[it].move_vector.y += 1;
            }
            if is_button_down(*g_input_states, .MOVE_LEFT) {
                player_commands[it].move_vector.x -= 1;
            }
            if is_button_down(*g_input_states, .MOVE_DOWN) {
                player_commands[it].move_vector.y -= 1;
            }
            if is_button_down(*g_input_states, .MOVE_RIGHT) {
                player_commands[it].move_vector.x += 1;
            }

            // Normalize the input vector to prevent diagonal movement being faster than horizontal
            if length_squared(player_commands[it].move_vector) > 1 {
                player_commands[it].move_vector = unit_vector(player_commands[it].move_vector);
            }

            if is_button_down(*g_input_states, .MAIN_ATTACK) {
                player_commands[it].main_attack = true;
            }
        }
    }
} @System @PostLoad

update_player_controllers :: (world: *World) {
    for query : Query(Player_Commands, *Player_Controller, *Velocity, Move_Speed, Anim_State_Component).{world = world} {
        player_commands := query.player_commands;
        player_controllers := query.player_controller;
        velocities := query.velocity;
        move_speeds := query.move_speed;
        anim_states := query.anim_state_component;

        for 0..query.count-1 {
            // @todo: is there a better way to block movement while attacking?
            current_anim_state := cast(Player_Anim_State) anim_states[it].state;
            velocity_from_input := player_commands[it].move_vector * move_speeds[it].speed;
            if current_anim_state == .ATTACK || current_anim_state == .ATTACK_WIND_UP {
                velocity_from_input = .{0, 0};
            }
            // update only by the delta in the velocity, since we already have change from last frame in the velocity component
            velocities[it].value += (velocity_from_input - player_controllers[it].velocity_from_input);
            player_controllers[it].velocity_from_input = velocity_from_input;
        }
    }
} @System @PreUpdate

broadcast_local_player_commands :: (world: *World) {
    for query : Query(Local_Player, Player_Commands, Networking_ID).{world = world} {
        player_commands := query.player_commands;
        networking_ids := query.networking_id;

        for 0..query.count-1 {
            player_command_packet: Player_Commands_Packet;
            player_command_packet.networking_id = networking_ids[it].id;
            player_command_packet.commands = player_commands[it];
            networking_send_packet(*player_command_packet);
        }
    }
} @System @OnUpdate

trigger_player_attack :: (world: *World) {
    log("Player attacked!");
} @Event


#import "Math";
