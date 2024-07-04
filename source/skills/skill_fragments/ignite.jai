Ignite :: struct @Component {}

add_ignite :: (world: *World, entity: Entity, value: s64) {
    add_component(world, entity, Ignite);
}

ignite :: (q: Query) {
    positions := query_get(q, Position);
    for 0..q.count-1 {
        entity := spawn_entity(*g_world, Sprite, Position, Duration);
        sprite := load_spritesheet("assets/orc_mage_walk_2.png",30, 0, 0,5,1);
        PLAYER_SIZE :: Vector2.{0.5, 0.5};

        << get_component(*g_world, entity, Sprite) =  .{sprite, PLAYER_SIZE, 0, 4, 0};
        << get_component(*g_world, entity, Position) = positions[it];
        << get_component(*g_world, entity, Duration) = .{5.0};
    }
} @System(OnUpdate) @Write() @Read(Ignite,Position)