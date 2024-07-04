Cooldown :: struct @Component {
    base_value: float;
    current_value: float;
}

update_cooldown :: (q: Query) {
    cooldowns := query_get(q, Cooldown);
    for 0..q.count-1 {

        if cooldowns[it].current_value > 0 {
            cooldowns[it].current_value -= FIXED_TIMESTEP;
        }

    }
} @System(OnUpdate) @Write(Cooldown) @Read() 