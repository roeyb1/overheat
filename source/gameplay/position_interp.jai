Interp_Position :: struct @Component {
    previous: Vector2;
    current: Vector2;
}

reset_interped_position_overrides :: (q: Query) {
    positions := query_get(q, Position);
    interp_positions := query_get(q, Interp_Position);

    for 0..q.count-1 {
        positions[it].value = interp_positions[it].current;
    }
} @System(PreUpdate) @Write(Position) @Read(Interp_Position)

set_previous_interped_positions :: (q: Query) {
    interp_positions := query_get(q, Interp_Position);

    for 0..q.count-1 {
        interp_positions[it].previous = interp_positions[it].current;
    }
} @System(PreUpdate) @Write(Interp_Position) @Read()

set_current_interped_positions :: (q: Query) {
    positions := query_get(q, Position);
    interp_positions := query_get(q, Interp_Position);

    for 0..q.count-1 {
        interp_positions[it].current = positions[it];
    }
} @System(PostUpdate) @Write(Interp_Position) @Read(Position)

update_interped_positions :: (q: Query) {
    positions := query_get(q, Position);
    interp_positions := query_get(q, Interp_Position);

    for 0..q.count-1 {
        positions[it].value = lerp(interp_positions[it].previous, interp_positions[it].current, g_interp_alpha);
    }
} @System(PreRender) @Write(Position) @Read(Interp_Position)
