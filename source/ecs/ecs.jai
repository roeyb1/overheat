World :: struct {
    stage: Stage;
    deferred_stage: Stage;

    deferred_ops: [..] ECS_Deferred_Operation;

    // maps type names to their unique cids
    cid_map: Table(string, s64);

    type_info_map: Table(s64, Component_Type_Info);

    min_id: s32 = 0;
    max_id: s32 = S32_MAX;

    is_deferring: bool = false;
}


ecs_world_init :: (using world: *World) {
    stage.world = world;
    deferred_stage.world = world;


    // bootstrap the component archetype:
    {
        bootstrap_component_id(world, EcsComponent, 0);
        arch := array_add(*stage.archetypes);
        arch_id := stage.archetypes.count-1;
        arch.id = arch_id;

        storage := array_add(*arch.storage);
        storage.component_size = type_info(EcsComponent).runtime_size;
        storage.initializer = type_info(EcsComponent).initializer;
        
        array_add(*arch.type_ids, cid_get(world, EcsComponent));

        ecs_add(world, entity_from_cid(0), EcsComponent.{runtime_size = type_info(EcsComponent).runtime_size}, broadcast=false);
    }

    // set up builtin components
    
    // we need to bootstrap EcsOnAdd and Event so they are available when the rest of the components are registered
    // component registration will fire off some (EcsOnAdd,EcsComponent) events
    bootstrap_component(world, EcsOnAdd, 1);
    bootstrap_component(world, Event, 2);

    for ALL_COMPONENT_TYPES {
        if it == EcsComponent then continue;
        if it == EcsOnAdd then continue;
        if it == Event then continue;
        cid_register(world, it);
    }

    register_static_events(world);
}

entity_is_valid :: (using world: World, entity: Entity) -> bool {
    return entity_is_alive(stage, entity);
}

entity_index_within_range :: (using world: *World, index: s32) -> bool {
    return index >= min_id && index < max_id;
}

entity_set_range :: (using world: *World, low: s32, high: s32) {
    world.min_id = low;

    if high == 0 {
        world.max_id = S32_MAX;
    } else {
        world.max_id = high;
    }

    if stage.entities.count < min_id {
        array_resize(*stage.entities, min_id);
    }

    // rebuild the free indices list now matching the new low and high ranges:
    array_reset_keeping_memory(*stage.free_indices);
    for stage.entities {
        if it.index == -1 && entity_index_within_range(world, cast(s32) it_index) {
            array_add(*stage.free_indices, cast(s32) it_index);
        }
    }
}

entity_spawn :: inline (using world: *World, components: ..Type, parent: Entity = INVALID_ENTITY, broadcast: bool = true) -> Entity {
    cids := cids_from_types(world, components);
    return entity_spawn(world, cids, parent, broadcast);
}

entity_spawn :: (using world: *World, components: [] s64, parent: Entity = INVALID_ENTITY, broadcast: bool = true) -> Entity {
    entity: Entity;
    if is_deferring {
        // if we're deferring, we will add an entity to the main stage and use that as the reference to the entity
        // this ensures that we have a stable id in case someone stores the id of the deferred entity.
        // We avoid adding any components to it so that it doesn't cause any reallocations of component tables which would break
        // all running systems.
        entity = entity_create(*stage, .[]);

        entity_defer_spawn(world, entity, components);
    } else {
        entity = entity_create(*stage, components);
    }

    if parent != INVALID_ENTITY {
        ecs_add_pair(world, entity, Child_Of, parent);
    }

    if broadcast {
        for cid : components {
            // truncate the cid here. If it the high bits are not empty, it's a pair and we can't represent Pair(Pair) with just 64 bits.
            // cid_low represents the source of the relationship so the consequences are that we will broadcast the event for any (EcsOnAdd,Target(*));

            cid_low := cast(s64) (cast,no_check(s32) cid);
            event_broadcast(world, cid_pair(world, EcsOnAdd, cid_low), entity);
        }
    }

    return entity;
}

ecs_entity_from_index :: (using world: *World, index: s32) -> Entity {
    entity := world.stage.entities[index];
    assert(entity_is_valid(world, entity));
    return entity;
}

entity_destroy :: (using world: *World, entity: Entity, broadcast: bool = true) {
    assert(entity_is_valid(world, entity));

    entity_destroy_children(world, entity, broadcast);

    if is_deferring {
        entity_defer_destroy(world, entity);
        return;
    }

    if broadcast {
        for type : entity_types_get(world, entity) {
            cid_lo := cid_low(type);

            event_broadcast(world, cid_pair(world, EcsOnRemove, cid_lo), entity);
        }
    }

    entity_delete(world, entity);
}

entity_delete :: (using world: *World, entity: Entity) {
    assert(!is_deferring);

    stage_entity_delete(*stage, entity);
}

ecs_has :: inline (using world: *World, entity: Entity, type: Type) -> bool {
    return ecs_has(world, entity, cid_get(world, type));
}

ecs_has :: (using world: *World, entity: Entity, cid: s64) -> bool {
    assert(entity_is_valid(world, entity));

    arch: *Archetype;
    if entity_is_alive(*deferred_stage, entity) {
        arch = entity_archetype_get(deferred_stage, entity);
    } else {
        arch = entity_archetype_get(stage, entity);
    }
    return archetype_type_has(arch, cid);
}

ecs_get :: (using world: *World, entity: Entity, $type: Type) -> *type {
    return cast(*type) ecs_get(world, entity, cid_get(world, type));
}

ecs_get :: (using world: *World, entity: Entity, cid: s64) -> *void {
    assert(entity_is_valid(world, entity));

    if entity_is_alive(*deferred_stage, entity) {
        return stage_component_get(deferred_stage, entity, cid);
    }

    return stage_component_get(stage, entity, cid);
}

ecs_get_target :: (using world: *World, entity: Entity, type: Type, index: s64 = 0) -> Entity {
    assert(entity_is_valid(world, entity));

    if entity_is_alive(*deferred_stage, entity) {
        return stage_component_get_target(*deferred_stage, entity, type, index);
    }

    return stage_component_get_target(*stage, entity, type, index);
}

ecs_add :: (using world: *World, entity: Entity, val: $type, broadcast: bool = true) -> *type {
    ptr := cast(*type) ecs_add(world, entity, type, broadcast = false);
    ptr.* = val;
    if broadcast {
        // truncate the cid here. If it the high bits are not empty, it's a pair and we can't represent Pair(Pair) with just 64 bits.
        // cid_low represents the source of the relationship so the consequences are that we will broadcast the event for any (EcsOnAdd,Target(*));
        cid_lo := cid_low(cid_get(world, type));

        event_broadcast(world, cid_pair(world, EcsOnAdd, cid_lo), entity);
    }
    return ptr;
}

ecs_add_typed :: inline (using world: *World, entity: Entity, $type: Type, broadcast: bool = true) -> *type {
    return cast(*type) ecs_add(world, entity, cid_get(world, type), broadcast);
}

ecs_add :: inline (using world: *World, entity: Entity, type: Type, broadcast: bool = true) -> *void {
    return ecs_add(world, entity, cid_get(world, type), broadcast);
}

ecs_add :: (using world: *World, entity: Entity, cid: s64, broadcast: bool = true) -> *void {
    assert(entity_is_valid(world, entity));

    if ecs_has(world, entity, cid) {
        return ecs_get(world, entity, cid);
    }

    if entity_is_alive(deferred_stage, entity) {
        result := stage_component_add(*deferred_stage, entity, cid);
        if broadcast {
            event_broadcast(world, cid_pair(world, EcsOnAdd, cid_low(cid)), entity);
        }
        return result;
    }

    if is_deferring {
        return ecs_defer_add(world, entity, cid);
    }

    result := stage_component_add(*stage, entity, cid);

    if broadcast {
        // truncate the cid here. If it the high bits are not empty, it's a pair and we can't represent Pair(Pair) with just 64 bits.
        // cid_low represents the source of the relationship so the consequences are that we will broadcast the event for any (EcsOnAdd,Target(*));
        cid_lo := cid_low(cid);

        event_broadcast(world, cid_pair(world, EcsOnAdd, cid_lo), entity);
    }
    return result;
}

ecs_add_pair :: (using world: *World, entity: Entity, type: Type, target: Type, broadcast: bool = true) {
    ecs_add_pair(world, entity, type, cid_get(world, target), broadcast);
}

ecs_add_pair :: (using world: *World, entity: Entity, type: Type, target: Entity, broadcast: bool = true) {
    ecs_add_pair(world, entity, type, cast(s64) target.index, broadcast);
}

ecs_add_pair :: (using world: *World, entity: Entity, type: Type, target: s64, broadcast: bool = true) -> *void {
    pair_cid := cid_pair(world, type, target);
    return ecs_add(world, entity, pair_cid, broadcast);
}

ecs_remove :: (using world: *World, entity: Entity, type: Type, broadcast: bool = true) {
    ecs_remove(world, entity, cid_get(world, type));
}

ecs_remove :: (using world: *World, entity: Entity, cid: s64, broadcast: bool = true) {
    assert(entity_is_valid(world, entity));
    assert(ecs_has(world, entity, cid));

    if is_deferring {
        ecs_defer_remove(world, entity, cid, broadcast);
        return;
    }

    if broadcast {
        // truncate the cid here. If it the high bits are not empty, it's a pair and we can't represent Pair(Pair) with just 64 bits.
        // cid_low represents the source of the relationship so the consequences are that we will broadcast the event for any (EcsOnRemove,Target(*));
        cid_lo := cid_low(cid);

        event_broadcast(world, cid_pair(world, EcsOnRemove, cid_lo), entity);
    }

    stage_component_remove(*stage, entity, cid);
}

entity_types_get :: (using world: *World, entity: Entity) -> [] s64 {
    assert(entity_is_valid(world, entity));

    if entity_is_alive(deferred_stage, entity) {
        return stage_entity_get_types(*deferred_stage, entity);
    }
    return stage_entity_get_types(*stage, entity);
}

ecs_singleton_get :: (using world: *World, $type: Type) -> *type {
    cid := cid_get(world, type);
    entity := entity_from_cid(cid);

    ptr := ecs_get(world, entity, type);
    assert(ptr != null); // singletons cannot ever return null
    return ptr;
}

#scope_file

bootstrap_component_id :: (using world: *World, type: Type, id: s64) {
    entity := entity_from_raw(id);
    entity_make(*world.stage, entity, .[]);
    assert((cast(*Type_Info)type).type == .STRUCT);
    table_add(*cid_map, (cast(*Type_Info_Struct)type).name, entity.raw);

    cti := get_component_type_info(type);
    cti.cid = entity.raw;
    table_add(*type_info_map, entity.raw, cti);
}

bootstrap_component :: (using world: *World, type: Type, id: s64) {
    entity := entity_from_raw(id);
    entity_make(*world.stage, entity, .[]);

    assert((cast(*Type_Info)type).type == .STRUCT);
    table_add(*cid_map, (cast(*Type_Info_Struct)type).name, entity.raw);

    cti := get_component_type_info(type);
    cti.cid = entity.raw;
    table_add(*type_info_map, entity.raw, cti);

    ecs_add(world, entity, EcsComponent.{runtime_size = cti.ti.runtime_size}, broadcast=false);
}

entity_destroy_children :: (using world: *World, parent: Entity, broadcast: bool = true) {
    children: [..] Entity;
    children.allocator = temp;

    for * iter : iter_make_pair(world, Child_Of, parent) {
        for iter.entities {
            array_add(*children, it);
        }
    }

    for children {
        entity_destroy(world, it, broadcast);
    }
}

#scope_export

#load "stage.jai";
#load "entity.jai";
#load "component.jai";
#load "defer.jai";
#load "archetype.jai";
#load "storage.jai";
#load "system.jai";
#load "event.jai";
#load "relations.jai";
#load "bundle.jai";
#load "query.jai";
#load "iter.jai";

#load "tests/entity.jai";
#load "tests/stage.jai";
#load "tests/event.jai";
#load "tests/query.jai";