#scope_export 

Player :: struct @Tag {}

Local_Player :: struct @Tag {}
Remote_Player :: struct @Tag {}

Player_Controller :: struct @Component {
    // Keep track of the velocity added due to user input
    velocity_from_input: Vector2;
}

Networked :: struct @Tag {}

/** Player commands are not directly synced through the replication framwork, they are instead manually sent to the server. */
Player_Commands :: struct @Component {
    move_vector: Vector2;

    main_attack: bool;
    secondary_attack: bool;

    cursor_position: Vector2;
}

operator== :: (a: Player_Commands, b: Player_Commands) -> bool {
    return a.move_vector == b.move_vector && a.main_attack == b.main_attack && a.secondary_attack == b.secondary_attack;
}

Player_Bundle :: struct @Bundle {
    player: Player;
    velocity: Velocity;
    name: Name;
    player_commands: Player_Commands;
    position: Position;
    move_speed: Move_Speed;
    point_light: Point_Light;
    invoker: Collision_Invoker;
    animation: Player_Animation;
    animator: Sprite_Animator;
    dir: Direction;
    player_controller: Player_Controller;
    sprite: Sprite;
    collider: Collider_AABB;
    health: Health;
    health_change_queue: Health_Change_Queue;
    networking_id: Networked;
    remote: Remote_Player;
    cooldown: Cooldown;
    anim_info: Interuptor_Anim_Slot;
    stored_power: Stored_Power;
}

init_player :: (position: Vector2) -> Entity {
    spritesheet := "assets/players/player_character1.png";

    PLAYER_SIZE :: Vector2.{2.3, 2.3};
    PLAYER_COLLIDER_SIZE :: Vector2.{1., 1.};

    entity := entity_spawn(*g_world);

    ecs_add_bundle(*g_world, entity, Player_Bundle.{
        name = .{ sprint("Player_%", entity.index) },
        position = .{ position },
        invoker = .{ id = cast(u64) entity.raw },
        move_speed =  .{ 6 },
        point_light = .{ intensity = 1., color = .{ 255. / 255., 197. / 255., 143. / 255. }, radius = 20. },
        sprite = .{ spritesheet, null, PLAYER_SIZE, 0, 4, 0 },
        collider = .{ aabb = make_aabb(.{ 0, 0 }, PLAYER_COLLIDER_SIZE) },
        health = .{90., 100.},
        cooldown = .{base_value=1.},
    });

    // set up a test inventory
    inventory := entity_spawn(*g_world, Networked);
    ecs_add_pair(*g_world, entity, Inventory, inventory);

    sword := entity_spawn(*g_world, Item, Sword, Networked);
    ecs_add(*g_world, sword, Name.{"Sword"});

    helmet := entity_spawn(*g_world, Item, Helmet, Networked);
    ecs_add(*g_world, helmet, Name.{"Helmet"});

    ecs_add_pair(*g_world, sword, ContainedBy, inventory);
    ecs_add_pair(*g_world, helmet, ContainedBy, inventory);

    return entity;
}

#if CLIENT {
update_local_player_commands_from_input :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    input_states := ecs_singleton_get(q.world, Input_States);

    for 0..q.count-1 {
        // reset previous frame's command state:
        memset(*player_commands[it], 0, size_of(Player_Commands));

        if is_button_down(input_states, .MOVE_UP) {
            player_commands[it].move_vector.y += 1;
        }
        if is_button_down(input_states, .MOVE_LEFT) {
            player_commands[it].move_vector.x -= 1;
        }
        if is_button_down(input_states, .MOVE_DOWN) {
            player_commands[it].move_vector.y -= 1;
        }
        if is_button_down(input_states, .MOVE_RIGHT) {
            player_commands[it].move_vector.x += 1;
        }

        // Normalize the input vector to prevent diagonal movement being faster than horizontal
        if length_squared(player_commands[it].move_vector) > 1 {
            player_commands[it].move_vector = unit_vector(player_commands[it].move_vector);
        }

        if is_button_down(input_states, .MAIN_ATTACK) {
            player_commands[it].main_attack = true;
        }

        if is_button_down(input_states, .SECONDARY_ATTACK) {
            player_commands[it].secondary_attack = true;
        }

        player_commands[it].cursor_position = get_mouse_worldspace();
    }
} @System(PostLoad) @Write(Player_Commands) @Read(Local_Player,Input_States)
}

update_player_controllers :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    player_controllers := query_get(q, Player_Controller);
    velocities := query_get(q, Velocity);
    move_speeds := query_get(q, Move_Speed);

    for 0..q.count-1 {
        velocity_from_input := player_commands[it].move_vector * move_speeds[it].speed;
        // update only by the delta in the velocity, since we already have change from last frame in the velocity component
        velocities[it].value += (velocity_from_input - player_controllers[it].velocity_from_input);
        player_controllers[it].velocity_from_input = velocity_from_input;
    }
} @Predict @System(PreUpdate) @Write(Player_Controller,Velocity) @Read(Player_Commands,Move_Speed)

#if CLIENT {
broadcast_local_player_commands :: (q: Query) {
    player_commands := query_get(q, Player_Commands);

    for 0..q.count-1 {
        player_command_packet: Player_Commands_Packet;
        player_command_packet.node_id = q.entities[it].raw;
        player_command_packet.commands = player_commands[it];
        player_command_packet.tick = g_current_tick;
        networking_send_packet(*player_command_packet);
        // we should only have one local player, so this should only happen once
        input_ring[g_current_tick % input_ring.count] = player_commands[it];
    }
} @System(PostLoad) @Write() @Read(Local_Player,Player_Commands,Networked)
}

on_player_component_added :: (world: *World, entity: Entity) {
    log("Player % (%) has joined the game", ecs_get(world, entity, Name).name, entity.index);

    #if CLIENT {
        networking_id := ecs_get(world, entity, Networked);
        assert(networking_id != null);
        if entity.raw == g_client.local_client_id {
            ecs_remove(*g_world, entity, Remote_Player);
            ecs_add(*g_world, entity, Local_Player);

            sprite := ecs_get(world, entity, Sprite);
            sprite.sheet = null;
            sprite.sheet_path = "assets/players/player_character1.png";
        }

        print_inventory(*g_world, entity);
    }
} @Event(EcsOnAdd,Player)

#if CLIENT {
get_mouse_worldspace :: () -> Vector2 {
    viewport := ecs_singleton_get(*g_world, Game_Viewport);
    camera := ecs_get(*g_world, viewport.main_camera, Camera);
    cam_pos := ecs_get(*g_world, viewport.main_camera, Position);
    s_x, s_y := get_mouse_cursor_pos();
    v := viewspace_to_worldspace(camera.projection, cam_pos, .{cast(float)s_x, cast(float)s_y});
    return v;
}
}

on_player_component_removed :: (world: *World, entity: Entity) {
    log("Player % (%) has left the game", ecs_get(world, entity, Name).name, entity.index);
} @Event(EcsOnRemove,Player)

#import "Math";
