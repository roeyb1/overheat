Energy_Cost :: struct @Component {
    total: float; 
    per_tick: float; 
}

//if there is no duration componenet the base cost of an ability will be considered as the cost per second
calculate_energy_cost_per_tick :: (world: *World, entity: Entity) {
        energy_cost := ecs_get(world, entity, Energy_Cost);
        duration := ecs_get(world, entity, Duration);

        if (duration) {
            number_of_ticks := duration.base_value/FIXED_TIMESTEP;
            if number_of_ticks > 1 {
                energy_cost.per_tick = energy_cost.total / number_of_ticks;
            }
            else {
                energy_cost.per_tick = energy_cost.total;
            }
        }
        else {
           energy_cost.per_tick = 1/FIXED_TIMESTEP; 
        } 
} @Event(EcsOnAdd,Energy_Cost)

drain_energy_per_tick :: (change_queue: Health_Change_Queue, energy_cost: Energy_Cost) {
    array_add(*change_queue.changes, -energy_cost.per_tick);
}

