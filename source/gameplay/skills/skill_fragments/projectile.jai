Projectile :: struct @Component {
    direction: Vector2;
}

add_projectile :: (world: *World, skill: Entity){
    parent := get_parent(world, skill);
    if is_valid(world,parent){
            {
                
                spritesheet := "assets/skills/blue_orb.png";
                PLAYER_SIZE :: Vector2.{2.3, 2.3};    

                sprite := load_spritesheet("assets/particles/blue_orb.png",48, 0, 0,23,6);
                SPRITE_SIZE :: Vector2.{1., 1.};
                add_component(world, skill, Sprite, .{spritesheet, null, PLAYER_SIZE, 0, 4, 0});

                spawn_location := get_component(world, parent, Position).value;
                log("%",spawn_location);
                add_component(world, skill, Position, .{spawn_location});


                targeting := get_component(world, parent, Current_Target).value;
                direction := unit_vector(targeting-spawn_location);

            
                add_component(world, skill, Projectile, .{direction});
                add_component(world, skill, Velocity);

                add_component(world, skill, Move_Speed, .{speed = 1});
                //add_component(world, skill, Interp_Position, .{spawn_location,spawn_location});
            }
    }
}

projectile_movement :: (q: Query) {
    projectiles := query_get(q, Projectile);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projectiles[it].direction * movement_speeds[it].speed;
    }
} @System(OnUpdate) @Write(Velocity) @Read(Projectile,Move_Speed)