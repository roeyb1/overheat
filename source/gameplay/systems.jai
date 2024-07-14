update_positions :: (q: Query) {
    positions := query_get(q, Position);
    velocities := query_get(q, Velocity);

    for 0..q.count-1 {
        positions[it].value = positions[it] + velocities[it] * FIXED_TIMESTEP;
    }
} @System(OnUpdate) @Write(Position) @Read(Velocity)
