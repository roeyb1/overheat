//the power that will live on skills and define their potency
Power :: struct @Component {
    total: float;
    incoming: float;
}

Energy_Change_Queue :: struct @Component {
    changes: [..] float;
}

PoweredBy :: struct @Pair { }

//this is for the power on skills this is where the math will happen to translate the incoming energy from the energy change queue into power output
modify_power :: (q: Query) {
    power_components := query_get(q, Power);
    energy_change_queues := query_get(q, Energy_Change_Queue);

    for 0..q.count-1 {
        power_components[it].incoming = 0.;
        for change : energy_change_queues[it].changes {
            power_components[it].total += change;
            power_components[it].incoming += change;
        }

        // reset the queue for next frame
        energy_change_queues[it].changes.count = 0;

        if power_components[it].total < 0 {
            entity_destroy(q.world, q.entities[it]);
        }
    }
} @System(OnValidate) @Write(Power) @Read(Energy_Change_Queue)

//every tick a skill is powering up it will absorb the energy granted to it by the thing powerign it
power_skill_per_tick :: (q: Query) {
    gathered_energies := query_get(q, Gathered_Energy);

    for 0..q.count-1 {
        for * iter : iter_make_pair(q.world, PoweredBy, q.entities[it],Powering_Up) {
           
            distributed_power := gathered_energies[it].value/iter.count;

            energy_change_queue := ecs_get(q.world, iter.entities[it], Energy_Change_Queue);
            if energy_change_queue {
                power_skill(energy_change_queue, distributed_power);
            }
        } 
        gathered_energies[it].value = 0;
    }
} @System(OnValidate) @Write(Gathered_Energy) @Read()

power_skill :: (change_queue: Energy_Change_Queue, power: float) {
    array_add(*change_queue.changes, power);
}

