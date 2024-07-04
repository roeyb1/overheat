Project :: struct @Component {
    direction: Vector2;
}

Project_Bundle :: struct @Bundle {
    skill_definition: Skill_Definition;
    networking_id: Networking_ID;
    name: Name;
    fragments: Fragments;
    to_cast: To_Cast;
    cooldown: Cooldown;
}

add_project :: (world: *World, skill: Entity, value: s64, casting_entity: Entity) {

    << get_component(world, skill, Target_Entity) = .{skill};

    sprite := load_spritesheet("assets/players/player_character1.png",48, 0, 0,23,4);
    PLAYER_SIZE :: Vector2.{2.3, 2.3};
    add_component(world, skill, Sprite, .{sprite, PLAYER_SIZE, 0, 4, 0});


    spawn_location := get_component(world, casting_entity, Position);
    add_component(world, skill, Position, .{spawn_location});


    targeting := get_component(world, casting_entity, Current_Target).value;
    direction := unit_vector(targeting-spawn_location);

   
    add_component(world, skill, Project, .{direction});
    add_component(world, skill, Velocity);

    add_component(world, skill, Move_Speed, .{base_value = 1});
    add_component(world, skill, Interp_Position, .{spawn_location,spawn_location});

    compute_attribute(get_component(*g_world,skill,Move_Speed));
}

project_movement :: (q: Query) {
    projects := query_get(q, Project);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projects[it].direction * movement_speeds[it].value;
    }
} @System(OnUpdate) @Write(Velocity) @Read(Project,Move_Speed)