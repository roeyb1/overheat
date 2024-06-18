Interp_Position :: struct {
    previous: Vector2;
    current: Vector2;
} @Component

reset_interped_position_overrides :: (world: *World) {
    for query : Query(*Position, Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;

        for 0..query.count-1 {
            positions[it].value = interp_positions[it].current;
        }
    }
} @System @PreUpdate

set_current_interped_positions :: (world: *World) {
    for query : Query(Position, *Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;

        for 0..query.count-1 {
            interp_positions[it].previous = interp_positions[it].current;
            interp_positions[it].current = positions[it];
        }
    }
} @System @PostUpdate

update_interped_positions :: (world: *World) {
    for query : Query(*Position, Interp_Position).{world = world} {
        positions := query.position;
        interp_positions := query.interp_position;

        for 0..query.count-1 {
            positions[it].value = interp_positions[it].current * g_interp_alpha + interp_positions[it].previous * (1. - g_interp_alpha);
        }
    }
} @System @PreRender
