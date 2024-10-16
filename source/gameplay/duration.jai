Duration :: struct @Component { 
    value: float; @Sync
    base_value: float; @Sync
}

update_duration :: (q: Query) {
    durations := query_get(q, Duration);
    for 0..q.count-1 {
        durations[it].value -= FIXED_TIMESTEP;
        
        if durations[it].value < 0 {
            entity_destroy(q.world, q.entities[it]);
        }
    }
} @System(PostUpdate) @Write(Duration) @Read() 

reset_duration :: (world: *World, entity: Entity) {
    duration := ecs_get(world, entity, Duration);
    duration.value = duration.base_value;
} @Event(EcsOnAdd,Duration)

