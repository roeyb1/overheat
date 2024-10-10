Placeholder :: struct @Component {}

Duration :: struct @Component {
    value: float = 0.5; @Sync
    base_value: float;
}

update_duration :: (q: Query) {
    durations := query_get(q, Duration);
    for 0..q.count-1 {
        durations[it].value -= FIXED_TIMESTEP;
        
        if durations[it].value < 0 {
            entity_destroy(q.world, q.entities[it]);
        }
    }
}  @System(PostUpdate) @Write(Duration) @Read() @OptionalRead(Placeholder)

set_base_duration :: (world: *World, entity: Entity) {
    duration := ecs_get(world, entity, Duration);
    duration.base_value = duration.value;
} @Event(EcsOnAdd,Duration)