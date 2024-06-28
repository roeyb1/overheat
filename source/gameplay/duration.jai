Duration :: struct @Component {
    value: float = 1.;
}

update_duration :: (q: Query) {
    durations := query_get(q, Duration);
    for 0..q.count-1 {
        durations[it].value -= FIXED_TIMESTEP;
        
        if durations[it].value < 0 {
            destroy_entity(q.world, q.entities[it]);
        }
    }
} @System(OnValidate) @Write(Duration) @Read() 