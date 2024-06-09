Event_ID :: s32;

ECS_EVENT_ON_ADD: Event_ID = -1;
ECS_EVENT_ON_REMOVE: Event_ID = -1;

Event_Listener :: struct {
    callback: Event_Callback;
}

Event_Callback :: #type (world: *World) -> ();

Event_List :: struct {
    /** Event ids correspond to an index in this array. That index contains the list of event listeners that are registered to that event. */
    event_listeners: [..][..] Event_Listener;
}

init_ecs_events :: () {
    // register all the internal ecs events:
    ECS_EVENT_ON_ADD = register_event();
    ECS_EVENT_ON_REMOVE = register_event();
}

register_event :: () -> Event_ID {
    val := array_add(*g_event_list.event_listeners);
    return cast(s32) g_event_list.event_listeners.count - 1;
}

register_event_listener :: (event_id: Event_ID, callback: Event_Callback) {
    // ensure the event_id is valid
    assert(event_id != -1);
    assert(event_id < g_event_list.event_listeners.count);

    array_add(*g_event_list.event_listeners[event_id], .{callback});
}

broadcast_event :: (world: *World, event_id: Event_ID) {
    // ensure the event_id is valid
    assert(event_id != -1);
    assert(event_id < g_event_list.event_listeners.count);

    for g_event_list.event_listeners[xx event_id] {
        it.callback(world);
    }
}

#scope_file

g_event_list: Event_List;