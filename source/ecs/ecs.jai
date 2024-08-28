World :: struct {
    stage: Stage;
    deferred_stage: Stage;

    deferred_ops: [..] ECS_Deferred_Operation;

    // maps type names to their unique cids
    cid_map: Table(string, s64);

    type_info_map: Table(s64, Component_Type_Info);

    is_deferring: bool = false;
}

ecs_world_init :: (using world: *World) {
    stage.world = world;
    deferred_stage.world = world;

    // set up builtin components
    ecs_component := Entity.{ index = 0, generation = 0 };
    entity_make(*world.stage, ecs_component, .[]);

    table_add(*cid_map, type_info(ECS_Component).name, ecs_component.raw);

    stage_bootstrap(*stage);
    stage_bootstrap(*deferred_stage);

    for ALL_COMPONENT_TYPES {
        cid_register(world, it);
    }
}

entity_is_valid :: (using world: World, entity: Entity) -> bool {
    return entity_is_alive(stage, entity);
}

entity_spawn :: inline (using world: *World, components: ..Type, parent: Entity = INVALID_ENTITY) -> Entity {
    cids := cids_from_types(world, components);
    return entity_spawn(world, cids, parent);
}

entity_spawn :: (using world: *World, components: [] s64, parent: Entity = INVALID_ENTITY) -> Entity {
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

    return entity;
}

entity_destroy :: (using world: *World, entity: Entity) {
    assert(entity_is_valid(world, entity));

    if entity_defer_destroy(world, entity) {
        return;
    }

    entity_delete(world, entity);
}

entity_delete :: (using world: *World, entity: Entity) {
    assert(!is_deferring);

    entity_destroy_children(world, entity);

    stage_entity_delete(*stage, entity);
}

ecs_has :: (using world: *World, entity: Entity, cid: s64) -> bool {
    return ecs_get(world, entity, cid) != null;
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

ecs_get_target :: (using world: *World, entity: Entity, type: Type) -> Entity {
    // #todo: implement
    assert(false);
    return INVALID_ENTITY;
}

ecs_add :: (using world: *World, entity: Entity, $type: Type, val: type) -> *type {
    ptr := cast(*type) ecs_add(world, entity, type);
    ptr.* = val;
    return ptr;
}

ecs_add :: (using world: *World, entity: Entity, $type: Type) -> *type {
    return cast(*type) ecs_add(world, entity, cid_get(world, type));
}

ecs_add :: (using world: *World, entity: Entity, cid: s64) -> *void {
    assert(entity_is_valid(world, entity));

    existing := ecs_get(world, entity, cid);
    if existing then return existing;

    if entity_is_alive(deferred_stage, entity) {
        result := stage_component_add(*deferred_stage, entity, cid);
        return result;
    }

    if is_deferring {
        return ecs_defer_add(world, entity, cid);
    }

    result := stage_component_add(*stage, entity, cid);
    return result;
}

ecs_add_pair :: (using world: *World, entity: Entity, $type: Type, target: Entity) -> *type {
    pair_cid := cid_pair(world, type, target);
    return cast(*type) ecs_add(world, entity, pair_cid);
}

ecs_remove :: (using world: *World, entity: Entity, type: Type) -> bool {
    return ecs_remove(world, entity, cid_get(world, type));
}

ecs_remove :: (using world: *World, entity: Entity, cid: s64) -> bool {
    assert(entity_is_valid(world, entity));

    if entity_is_alive(deferred_stage, entity) {
        removed := stage_component_remove(*deferred_stage, entity, cid);
        return removed;
    }

    if is_deferring {
        return ecs_defer_remove(world, entity, cid);
    }

    removed := stage_component_remove(*stage, entity, cid);
    return removed;
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
    if !ptr {
        ptr = ecs_add(world, entity, type);
    }
    return ptr;
}

#scope_file


entity_destroy_children :: (using world: *World, parent: Entity) {
    children: [..] Entity;
    children.allocator = temp;

    for * iter : iter_make_pair(world, Child_Of, parent) {
        for iter.entities {
            array_add(*children, it);
        }
    }

    for children {
        entity_delete(world, it);
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

#load "tests/entity.jai";
#load "tests/stage.jai";