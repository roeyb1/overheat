Health_Change_Queue :: struct @Component {
    changes: [..] float;
}

Health :: struct @Component {
    value: float; @Sync
    max: float; @Sync
}

modify_health :: (q: Query) {
    health_components := query_get(q, Health);
    health_change_queues := query_get(q, Health_Change_Queue);

    for 0..q.count-1 {
        for change : health_change_queues[it].changes {
            health_components[it].value += change;
        }

        // reset the queue for next frame
        health_change_queues[it].changes.count = 0;

        if health_components[it].value <= 0 {
            destroy_entity(q.world, q.entities[it]);
        }
    }
} @System(OnValidate) @Write(Health) @Read(Health_Change_Queue)
