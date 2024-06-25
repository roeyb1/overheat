Enemy_Type :: enum {
    INVALID;
    BAT;
    SKELETON;
}

Enemy :: struct @Component {
    type: Enemy_Type;
}

spawn_enemy :: (world: *World, position: Vector2, type: Enemy_Type) {
    entity := spawn_entity(world, Enemy, Position, Velocity, Interp_Position, Move_Speed, Sprite, Animation, Anim_State_Component, Direction, Collision_Invoker, Collider_AABB);

    << get_component(world, entity, Position) = .{position};
    << get_component(world, entity, Interp_Position) = .{position, position};
    << get_component(world, entity, Move_Speed) =  .{3};
    get_component(world, entity, Enemy).type = type;

    size: Vector2;
    collider_size: Vector2;
    sprite: *SpriteSheet;

    if type == {
        case .SKELETON;
            size = Vector2.{1.0, 1.0};
            collider_size = Vector2.{0.6, 0.6};
            sprite = load_spritesheet("assets/enemies/skeleton.png", 32, 0, 0, 10, 4);
        case .BAT;
            size = Vector2.{2.3, 2.3};
            collider_size = Vector2.{0.6, 0.6};
            sprite = load_spritesheet("assets/enemies/bat2.png", 96, 0, 0, 15, 4);
            << get_component(world, entity, Animation) = .{ BAT_IDLE_DEFINITION, 0, BAT_IDLE_DEFINITION.frame_duration, false};
    }

    << get_component(world, entity, Sprite) = .{sprite, size, 0, 4, 0};
    << get_component(world, entity, Collider_AABB) = .{aabb = make_aabb(.{0, 0}, collider_size)};
}

track_player :: (q: Query) {
    velocities := query_get(q, Velocity);
    move_speeds := query_get(q, Move_Speed);
    positions := query_get(q, Position);

    for 0..q.count-1 {
        velocities[it].value = unit_vector(get_component(q.world, g_local_player, Position) - positions[it]) * move_speeds[it].speed;
    }
} @System(PreUpdate) @Write(Velocity) @Read(Enemy,Move_Speed,Position)
