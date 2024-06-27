Enemy_Type :: enum {
    INVALID;
    BAT;
    SKELETON;
}

Enemy :: struct @Component {
    type: Enemy_Type;
}

Enemy_Bundle :: struct @Bundle {
    enemy: Enemy;
    position: Position;
    velocity: Velocity;
    interp_position: Interp_Position;
    sprite: Sprite;
    animator: Sprite_Animator;
    direction: Direction;
    invoker: Collision_Invoker;
    collider: Collider_AABB;;
}

spawn_enemy :: (world: *World, position: Vector2, type: Enemy_Type) {
    entity := spawn_from_bundle(world, Enemy_Bundle.{
        position = .{ position },
        interp_position = .{ position, position },
        enemy.type = type,
    });

    add_components_from_bundle(world, entity, Follower.{
        move_speed.speed = 3,
        follow = .{
            mode = .TAG,
            tag = #run component_type_id(Player),
            max_distance = 5,
        },
    });

    size: Vector2;
    collider_size: Vector2;
    sprite: *SpriteSheet;

    if type == {
        case .SKELETON;
            size = Vector2.{1.0, 1.0};
            collider_size = Vector2.{0.6, 0.6};
            sprite = load_spritesheet("assets/enemies/skeleton.png", 32, 0, 0, 10, 4);
            add_component(world, entity, Skeleton_Animation);
        case .BAT;
            size = Vector2.{2.3, 2.3};
            collider_size = Vector2.{0.6, 0.6};
            sprite = load_spritesheet("assets/enemies/bat2.png", 96, 0, 0, 15, 4);
            add_component(world, entity, Bat_Animation);
    }

    << get_component(world, entity, Sprite) = .{sprite, size, 0, 4, 0};
    << get_component(world, entity, Collider_AABB) = .{aabb = make_aabb(.{0, 0}, collider_size), blocking = false};
}