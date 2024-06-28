Project :: struct @Component {
    direction: Vector2;
}

add_project :: (world: *World, entity: Entity, value: s64, casting_entity: Entity) {

    sprite := load_spritesheet("assets/players/player_character1.png",48, 0, 0,23,4);
    PLAYER_SIZE :: Vector2.{2.3, 2.3};
    add_component(world, entity, Sprite, .{sprite, PLAYER_SIZE, 0, 4, 0});


    spawn_location := get_component(world, casting_entity, Position);
    add_component(world, entity, Position, .{spawn_location});


    targeting := get_component(world, casting_entity, Current_Target).value;
    direction := unit_vector(targeting-spawn_location);

   
    add_component(world, entity, Project, .{direction});
    add_component(world, entity, Velocity);

    add_component(world, entity, Move_Speed, .{1});
}

project_movement :: (q: Query) {
    projects := query_get(q, Project);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projects[it].direction * movement_speeds[it].speed;
    }
} @System(OnUpdate) @Write(Velocity) @Read(Project,Move_Speed)