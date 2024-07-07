channel :: struct {
    duration: float;
    energy_cost: float;
    power_output: float;
}

start_channeling :: (world: *World, player: Entity) {
    channel := spawn_child_entity(world, player);
}

Power_Up_Skills :: (q: Query) {}