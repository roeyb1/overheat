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
    animator: Sprite_Animator;
    direction: Direction;
    invoker: Collision_Invoker;
    collider: Collider_AABB;
    networking_id: Networking_ID;
    health: Health;
}

spawn_enemy :: (world: *World, position: Vector2, node_id: Node_ID, type: Enemy_Type) {
    entity := spawn_entity_from_bundle(world, Enemy_Bundle.{
        position = .{ position },
        enemy.type = type,
        networking_id.id = node_id,
        health = .{100., 100.},
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
    spritesheet_path: string;

    if type == {
        case .SKELETON;
            size = Vector2.{1.0, 1.0};
            collider_size = Vector2.{0.6, 0.6};
            spritesheet_path = "assets/enemies/skeleton.png";
            add_component(world, entity, Skeleton_Animation);
        case .BAT;
            size = Vector2.{2.3, 2.3};
            collider_size = Vector2.{0.6, 0.8};
            spritesheet_path = "assets/enemies/bat2.png";
            add_component(world, entity, Bat_Animation);
    }

    sprite := add_component(world, entity, Sprite, .{spritesheet_path, null, size, 0, 4, 0});
    << get_component(world, entity, Collider_AABB) = .{aabb = make_aabb(.{0, 0}, collider_size), blocking = false};
}

spawn_enemy_pack :: (world: *World, center: Vector2, radius: float, type: Enemy_Type) {
    assert(is_server(), "Spawn enemy pack called from client code! - This should only be called on the server");
    // for now, always just spawn 4 enemies around the center within radius distance:
    count :: 4;
    for 0..count-1 {
        angle := TAU * random_get_zero_to_one();
        distance := radius * random_get_zero_to_one();

        position := center + Vector2.{distance * cos(angle), distance * sin(angle)};
        spawn_enemy(world, position, get_unique_node_id(), .BAT);
    }
}