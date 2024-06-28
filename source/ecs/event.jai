
Event :: struct {
    callback: #type (world: *World, entity: Entity) -> ();
}

// maps CTID.unique_id to list of add events registered to it
on_add_listeners: Table(u64, [..] Event);


broadcast_on_component_add :: (world: *World, entity: Entity, ctid: Component_Type_ID) {
    listeners := table_find_pointer(*on_add_listeners, ctid.unique_id);
    if listeners == null then return;
    
    for << listeners {
        it.callback(world, entity);
    }
}
