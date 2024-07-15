Duration :: struct @Component {
    value: float = 0.5;
    base_value: float;
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

set_base_duration :: (world: *World, entity: Entity) {
    duration := get_component(world, entity, Duration);
    duration.base_value = duration.value;
} @Event(EcsOnAdd,Duration)