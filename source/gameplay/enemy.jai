Enemy :: struct @Component {}

spawn_enemy :: (world: *World, position: Vector2) {
    entity := spawn_entity(world, Enemy, Position, Velocity, Interp_Position, Move_Speed, Sprite, Animation, Anim_State_Component, Direction);

    << get_component(*g_world, entity, Position) = .{position};
    << get_component(*g_world, entity, Interp_Position) = .{position, position};
    << get_component(*g_world, entity, Move_Speed) =  .{3};

    ENEMY_SIZE :: Vector2.{1.0, 1.0};
    sprite := load_spritesheet("assets/enemies/skeleton.png", 32, 0, 0, 10, 4);
    << get_component(*g_world, entity, Sprite) = .{sprite, ENEMY_SIZE, 0, 4, 0};

    << get_component(*g_world, entity, Animation) = .{ENEMY_IDLE_DEFINITION,0,ENEMY_IDLE_DEFINITION.frame_duration, false};
}