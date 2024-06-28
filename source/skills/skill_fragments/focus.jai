Focus :: struct @Component {
    value: s64;
}

add_focus :: (world: *World, entity: Entity, value: s64) {
    add_component(world, entity, Focus, .{value});
    print("HEYA IM FOCUS\n");
}

focus_project :: (q: Query) {
    velocities := query_get(q, Velocity);
    positions := query_get(q, Position);
    for 0..q.count-1 {
        velocities[it].value = velocities[it].value + unit_vector(get_mouse_worldspace()-positions[it].value)*0.07;
    }
} @System(PreUpdate) @Write(Velocity) @Read(Focus,Local_Player,Project,Position)

