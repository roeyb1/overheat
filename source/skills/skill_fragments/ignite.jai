Ignite :: struct @Component {
}
Burning_Ground :: struct @Component {
    value: float;
}

add_ignite :: (world: *World, entity: Entity, value: s64, target_entity: Entity) {
    add_component(world,target_entity, Ignite);
    

    //find a better solution, idealy with systems
    if !get_component(world, entity, Projectile) {
        modifier := spawn_child_entity(world, target_entity, Ignite, Name);
        << get_component (world, modifier, Name) = .{"ignite"};
        add_component(world, modifier, Health_Value_Modifier, .{value = -5.});
    }
}


//should spawn a child of the projectile that does the ignite effect on a cooldown
ignite :: (q: Query) {
    positions := query_get(q, Position);
    ignites := query_get(q, Ignite);
    for 0..q.count-1 {
            entity := spawn_entity(*g_world, Sprite, Position, Duration, Burning_Ground, Collider_AABB, Collision_Invoker);
            sprite := load_spritesheet("assets/orc_mage_walk_2.png",30, 0, 0,5,1);
            PLAYER_SIZE :: Vector2.{0.5, 0.5};
            << get_component(q.world, entity, Burning_Ground) =  .{5.};
            << get_component(q.world, entity, Sprite) =  .{sprite, PLAYER_SIZE, 0, 4, 0};
            << get_component(q.world, entity, Collider_AABB) = .{aabb = make_aabb(.{0, 0}, .{0.6, 0.8}), blocking = false};
            << get_component(q.world, entity, Position) = positions[it];
            << get_component(q.world, entity, Duration) = .{5.0};
    }
    
} @System(OnUpdate) @Write() @Read(Ignite,Position)

Burning_Ground_Damage :: (world: *World, entity: Entity) {
    pair := get_component(world, entity, Overlap_Pair);
    a := pair.a;
    b := pair.b;

    if get_component(world, a, Burning_Ground) {
        if get_component(world, b, Current_Health){
            modifier := spawn_child_entity(world, b, Ignite, Name);
            << get_component (world, modifier, Name) = .{"ignite"};
            add_component(world, modifier, Health_Value_Modifier, .{value = -5.});
        }
    }

    if get_component(world, b, Burning_Ground) {
        if get_component(world, a, Current_Health){
            modifier := spawn_child_entity(world, b, Ignite, Name);
            << get_component (world, modifier, Name) = .{"ignite"};
            add_component(world, modifier, Health_Value_Modifier, .{value = -5.});
        }
    }
} @Event(EcsOnAdd,Overlap_Pair)




