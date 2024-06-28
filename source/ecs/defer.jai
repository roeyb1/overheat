Deferred_ECS_Op_Type :: enum {
    DESTROY;
    SPAWN;
    REMOVE_COMPONENT;
    ADD_COMPONENT;
}

Deferred_ECS_Operation :: struct {
    type: Deferred_ECS_Op_Type;
    entity: Entity;

    // used for component add/remove operations
    type_id: Component_Type_ID;
    // new component data is allocated from the temp allocator and will be copied into the entity when the op is processed.
    component_data: *void;
}

process_deferred_operations :: (world: *World) {
    assert(world.should_defer == false);

    for world.deferred_ops {
        if #complete it.type == {
            case .DESTROY;
                assert(!table_contains(*world.deferred_entities, it.entity.raw), "Deferred entities should be deleted immediately and not enter the deferred queue");
                if ensure(is_entity_valid(world, it.entity), "Destroyed entity is not valid") {
                    destroy_entity(world, it.entity);
                }
            case .SPAWN;
                // It's possible that the entity was destoyed in the staging world before we could copy it to the main world, very unlikely though
                if ensure(is_entity_valid(world, it.entity), "Spawned entity is not valid anymore") {
                    deferred, found := table_find(*world.deferred_entities, it.entity.raw);
                    assert(found);
                    copy_entity_between_deferred(world, it.entity, deferred);
                    remove_entity(*world.deferred_stage, deferred);
                }
            case .REMOVE_COMPONENT;
                // it's possible that the entity was destroyed before component removal was queued
                if is_entity_valid(world, it.entity) {
                    remove_component(*world.stage, it.entity, it.type_id);
                }
            case .ADD_COMPONENT;
                // it's possible that the entity was destroyed before component removal was queued
                if is_entity_valid(world, it.entity) {
                    ptr := add_component(*world.stage, it.entity, it.type_id);
                    memcpy(ptr, it.component_data, it.type_id.runtime_size);
                }
        }
    }
    assert((world.deferred_stage.entities.count - world.deferred_stage.free_entity_indices.count) == 0);
    world.deferred_ops.count = 0;
    table_reset(*world.deferred_entities);
}

#scope_file 

copy_entity_between_deferred :: (world: *World, to_entity: Entity, from_entity: Entity) {
    source_stage := *world.deferred_stage;
    dest_stage := *world.stage;

    s_record := table_find_pointer(*source_stage.entity_records, from_entity.raw);
    assert(s_record != null);

    from := *source_stage.archetypes[s_record.archetype_id];

    to, to_id := get_or_create_archetype(*world.stage, from.type_ids);

    d_record := table_find_pointer(*dest_stage.entity_records, to_entity.raw);
    assert(d_record != null);

    dest_row := add_entity(to, to_entity);
    if dest_row == 0 {
        add_archetype_to_active_cache(*world.stage, to, to_id);
    }

    d_record.row = dest_row;
    d_record.archetype_id = to_id;

    for ctid : from.type_ids {
        src_component, src_size := get_component(from, s_record.row, ctid);
        dst_component, dst_size := get_component(to, d_record.row, ctid);
        assert(src_size == dst_size);

        memcpy(dst_component, src_component, src_size);
    }
}
