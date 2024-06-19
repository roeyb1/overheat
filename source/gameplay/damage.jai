Health_Change_Queue :: struct @Component {
    changes: [..] float;
}

Health :: struct @Component {
    value: float;
}

modify_health :: (world: *World) {
    for query : Query(*Health, Health_Change_Queue).{world = world} {
        health_components := query.health;
        health_change_queues := query.health_change_queue;

        for 0..query.count-1 {
            for change : health_change_queues[it].changes {
                health_components[it].value += change;
            }

            // reset the queue for next frame
            health_change_queues[it].changes.count = 0;

            // @todo: kill the entity if health is negative
            if health_components[it].value <= 0 {

            }
        }
    }
} @System @OnValidate