Event_Callback :: #type (world: *World, entity: Entity) -> ();

Event_Listener :: struct {
    callback: Event_Callback;
    debug_name: string;
    event_id: *u64;
    ctid: Component_Type_ID;
}

Event :: struct {
    id: u64;

    // maps CTID.unique_id to list of add events registered to it
    listeners: Table(u64, [..] Event_Listener);
}

EcsOnAdd : u64 = #run generate_unique_event_id();
EcsOnRemove : u64 = #run generate_unique_event_id();

broadcast_on_component_add :: (world: *World, entity: Entity, ctid: Component_Type_ID) {
    broadcast_event(EcsOnAdd, world, entity, ctid);
}

broadcast_on_component_remove :: (world: *World, entity: Entity, ctid: Component_Type_ID) {
    broadcast_event(EcsOnRemove, world, entity, ctid);
}

broadcast_event :: (event_id: u64, world: *World, entity: Entity, ctid: Component_Type_ID) {
    if cast(s64)event_id > events.count-1 then return;

    listeners := table_find_pointer(*events[event_id].listeners, ctid.unique_id);
    if listeners != null {
        for << listeners {
            it.callback(world, entity);
        }
    }
    
    null_listeners := table_find_pointer(*events[event_id].listeners, NULL_COMPONENT_ID);
    if null_listeners != null {
        for << null_listeners {
            it.callback(world, entity);
        }
    }
}

generate_unique_event_id :: () -> u64 #compile_time {
    id := atomic_add(*NEXT_UNIQUE_EVENT_ID, 1);
    return id;
}

register_events :: () {
    max_event_id : u64 = 0; 
    for ALL_EVENT_LISTENERS if <<it.event_id > max_event_id then max_event_id = <<it.event_id;

    array_resize(*events, cast(s64) max_event_id + 1);
    for ALL_EVENT_LISTENERS {
        assert(cast(s64) (<<it.event_id) < events.count);

        listeners := find_or_add(*events[<<it.event_id].listeners, it.ctid.unique_id);
        array_add(listeners, it);
    }
}

register_event :: (listener: Event_Listener) {
    event_id := << listener.event_id;
    if cast(s64)(event_id) >= events.count {
        array_resize(*events, cast(s64) (event_id) + 1);
    }

    listeners := find_or_add(*events[event_id].listeners, listener.ctid.unique_id);
    array_add(listeners, listener);

    assert(EcsOnAdd != EcsOnRemove);
}

#placeholder ALL_EVENT_LISTENERS;

NEXT_UNIQUE_EVENT_ID : u64 = 1;

#scope_file

events: [..] Event;