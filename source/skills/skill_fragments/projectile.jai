Projectile:: struct @Component {
    direction: Vector2;
}

add_project:: (world: *World, skill: Entity, value: s64, casting_entity: Entity) {

    //future fragments will be applied to the projectile instead of the casting player
    << get_component(world, skill, Target_Entity) = .{skill};

    //by becoming a projectile the skill is manifested into the world, it is given a sprite and spawned on the casting entity to travel 
    //towards the targetted location
    {
        sprite := load_spritesheet("assets/players/player_character1.png",48, 0, 0,23,4);
        PLAYER_SIZE :: Vector2.{2.3, 2.3};
        add_component(world, skill, Sprite, .{sprite, PLAYER_SIZE, 0, 4, 0});

        spawn_location := get_component(world, casting_entity, Position);
        add_component(world, skill, Position, .{spawn_location});


        targeting := get_component(world, casting_entity, Current_Target).value;
        direction := unit_vector(targeting-spawn_location);

    
        add_component(world, skill, Projectile, .{direction});
        add_component(world, skill, Velocity);

        add_component(world, skill, Move_Speed, .{base_value = 1});
        add_component(world, skill, Interp_Position, .{spawn_location,spawn_location});

        compute_attribute(get_component(*g_world,skill,Move_Speed));
    }
}

projectile_movement :: (q: Query) {
    projectiles := query_get(q, Projectile);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projectiles[it].direction * movement_speeds[it].value;
    }
} @System(OnUpdate) @Write(Velocity) @Read(Projectile,Move_Speed)