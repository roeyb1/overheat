Interp_Position :: struct @Component {
    previous: Vector2;
    current: Vector2;
}

reset_interped_position_overrides :: (world: *World) {
    for query : Query(*Position, Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;

        for 0..query.count-1 {
            positions[it].value = interp_positions[it].current;
        }
    }
} @System(PreUpdate) @Write(Position) @Read(Interp_Position)

set_previous_interped_positions :: (world: *World) {
    for query : Query(Position, *Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;
        for 0..query.count-1 {
            interp_positions[it].previous = interp_positions[it].current;
        }
    }
} @System(PreUpdate) @Write(Interp_Position) @Read(Position)

set_current_interped_positions :: (world: *World) {
    for query : Query(Position, *Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;

        for 0..query.count-1 {
            interp_positions[it].current = positions[it];
        }
    }
} @System(PostUpdate) @Write(Interp_Position) @Read(Position)

update_interped_positions :: (world: *World) {
    for query : Query(*Position, Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;

        for 0..query.count-1 {
            positions[it].value = lerp(interp_positions[it].previous, interp_positions[it].current, g_interp_alpha);
        }
    }
} @System(PreRender) @Write(Position) @Read(Interp_Position)
