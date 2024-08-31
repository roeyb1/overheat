ECS_Deferred_Op_Type :: enum {
    DESTROY;
    SPAWN;
    REMOVE;
    ADD;
}

ECS_Deferred_Operation :: struct {
    type: ECS_Deferred_Op_Type;
    entity: Entity;

    cid: s64;
    component_data: *void;
}

entity_defer_spawn :: (using world: *World, entity: Entity, components: [] s64) {
    deferred_entity := entity_make(*deferred_stage, entity, components);

    array_add(*deferred_ops, .{type = .SPAWN, entity = entity });
}

entity_defer_destroy :: (using world: *World, entity: Entity) {
    assert(is_deferring);

    array_add(*deferred_ops, .{ type = .DESTROY, entity = entity });

    if entity_is_alive(deferred_stage, entity) {
        stage_entity_delete(*deferred_stage, entity);
    }
}

ecs_defer_add :: (using world: *World, entity: Entity, cid: s64) -> *void {
    assert(is_deferring);

    ci := ecs_get(world, entity_from_cid(cid), EcsComponent);

    ptr := talloc(ci.runtime_size);
    array_add(*deferred_ops, .{ type = .ADD, entity = entity, cid = cid, component_data = ptr });

    return ptr;
}


ecs_defer_remove :: (using world: *World, entity: Entity, cid: s64, broadcast: bool = true) {
    assert(is_deferring);

    if entity_is_alive(deferred_stage, entity) {
        if broadcast {
            // truncate the cid here. If it the high bits are not empty, it's a pair and we can't represent Pair(Pair) with just 64 bits.
            // cid_low represents the source of the relationship so the consequences are that we will broadcast the event for any (EcsOnRemove,Target(*));
            cid_lo := cid_low(cid);

            event_broadcast(world, cid_pair(world, EcsOnRemove, cid_lo), entity);
        }

        stage_component_remove(*deferred_stage, entity, cid);
        return;
    }

    array_add(*deferred_ops, .{ type = .REMOVE, entity = entity, cid = cid });
}

process_deferred_operations :: (using world: *World) {
    assert(is_deferring == false);
    assert(reentrant_guard == false);
    scoped_guard(*reentrant_guard, true);

    for world.deferred_ops {
        if #complete it.type == {
            case .DESTROY;
                assert(!entity_is_alive(*deferred_stage, it.entity), "Deferred entities should be deleted immediately and not enter the deferred queue");
                if entity_is_valid(world, it.entity) {
                    entity_destroy(world, it.entity);
                }
            case .SPAWN;
                // It's possible that the entity was destoyed in the staging world before we could copy it to the main world
                if entity_is_alive(world.stage, it.entity) {
                    move_entity_from_deferred(world, it.entity);
                }
            case .REMOVE;
                // it's possible that the entity was destroyed after component removal was queued
                if entity_is_alive(world.stage, it.entity) {
                    ecs_remove(world, it.entity, it.cid);
                }
            case .ADD;
                // it's possible that the entity was destroyed after component add was queued
                if entity_is_alive(world.stage, it.entity) {
                    ptr := ecs_add(world, it.entity, it.cid);
                    ci := ecs_get(world, entity_from_cid(it.cid), EcsComponent);
                    assert(ci != null);
                    memcpy(ptr, it.component_data, ci.runtime_size);
                    // ptr was allocated from temp storage, don't need to free it
                }
        }
    }
    assert(world.deferred_stage.entities.count == world.deferred_stage.free_indices.count);
    world.deferred_ops.count = 0;
}

#scope_file

reentrant_guard := false;

move_entity_from_deferred :: (using world: *World, entity: Entity) {
    assert(entity_is_alive(deferred_stage, entity));
    assert(entity_is_alive(stage, entity));

    def_record := entity_record_get_ptr(deferred_stage, entity);
    assert(def_record != null);
    record := entity_record_get_ptr(stage, entity);
    assert(record != null);

    from_arch := entity_archetype_get(deferred_stage, entity);
    to_arch := archetype_get_or_create(*stage, from_arch.type_ids);

    entity_storage_copy(*deferred_stage, *stage, to_arch, from_arch, entity);

    stage_entity_delete(*deferred_stage, entity);
}