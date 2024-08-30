Event_Callback :: #type (world: *World, entity: Entity) -> ();

EcsOnAdd :: struct @Pair { }
EcsOnRemove :: struct @Pair { }

Event :: struct @Component {
    desc: Event_Descriptor;
}

Event_Descriptor :: struct {
    callback: Event_Callback;
    debug_name: string;

    source: Type;
    opt_target: Type;
    has_target := false;
}

event_broadcast :: inline (world: *World, event: Entity, source: Entity) {
    event_broadcast(world, cid_from_entity(event), source);
}

event_broadcast :: (world: *World, cid: s64, source: Entity) {
    callbacks: [..] Event_Callback;
    callbacks.allocator = temp;

    for * q : iter_make_raw(world, .[cid, cid_get(world, Event)]) {
        events := query_get(q, Event);
        for 0..q.count-1 {
            array_add(*callbacks, events[it].desc.callback);
        }
    }
    for callbacks {
        it(world, source);
    }
}

register_static_events :: (using world: *World) {
    for desc : STATIC_EVENT_DESCS {
        event := entity_spawn(world);

        if desc.has_target {
            ecs_add_pair(world, event, desc.source, desc.opt_target);
        } else {
            ecs_add(world, event, cid_get(world, desc.source));
        }
        ecs_add(world, event, Event, .{desc});
    }
}

#placeholder STATIC_EVENT_DESCS;