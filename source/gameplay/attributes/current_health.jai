Current_Health :: struct @Component {
    using #as attrib: Dynamic_Attribute;
}

Health_Change_Queue :: struct @Component {
    using #as queue: Attribute_Change_Queue;
}

Health_Value_Modifier :: struct @Component {
    using #as modifier: Value_Modifier;
}

update_health :: (q: Query) {
    maximum_healths := query_get(q, Maximum_Health);
    current_healths := query_get(q, Current_Health);
    health_change_queues := query_get(q, Health_Change_Queue);

   
    for 0..q.count-1 {
        //ensure changes in maximum health are propagated to current health
        current_healths[it].maximum_value = maximum_healths[it].value;
        if current_healths[it].maximum_value < current_healths[it].current_value {
            current_healths[it].current_value = current_healths[it].maximum_value;
        }

        for change : health_change_queues[it].change_queue {
            current_healths[it].current_value += change;
            if current_healths[it].current_value > current_healths[it].maximum_value {
                current_healths[it].current_value = current_healths[it].maximum_value;
            }
        }

        // reset the queue for next frame
        health_change_queues[it].change_queue.count = 0;

        if current_healths[it].current_value <= 0 {
            destroy_entity(q.world, q.entities[it]);
        }
    }
} @System(OnValidate) @Write(Current_Health,Health_Change_Queue) @Read(Maximum_Health)

Queue_Current_Health_Modifier :: (world: *World, entity: Entity) {
    parent := get_parent(world, entity);
    health_queue := get_component(world, parent, Health_Change_Queue);
    health_value_modifier := get_component(world, entity, Health_Value_Modifier);
    
    array_add(*health_queue.change_queue,health_value_modifier.value);
    destroy_entity(world, entity);
} @Event(EcsOnAdd,Health_Value_Modifier)

