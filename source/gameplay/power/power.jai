//the power that will live on skills and define their potency
Power :: struct @Component {
    total: float;
    incoming: float;
}

//the power that lives on players and is distributed to skills
Stored_Power :: struct @Component {
    value: float;
}

Power_Change_Queue :: struct @Component {
    changes: [..] float;
}

gather_power :: (world: *World, parent: Entity, power: float) {
    stored_power := get_component(world, parent, Stored_Power);
    if stored_power {
        stored_power.value = power; 
    }
}

//this is for the power on skills
modify_power :: (q: Query) {
    power_components := query_get(q, Power);
    power_change_queues := query_get(q, Power_Change_Queue);

    for 0..q.count-1 {
        power_components[it].incoming = 0.;
        for change : power_change_queues[it].changes {
            power_components[it].total += change;
            power_components[it].incoming += change;
        }

        // reset the queue for next frame
        power_change_queues[it].changes.count = 0;

        if power_components[it].total < 0 {
            destroy_entity(q.world, q.entities[it]);
        }
    }
} @System(OnValidate) @Write(Power) @Read(Power_Change_Queue)


#load "power_skill.jai";
