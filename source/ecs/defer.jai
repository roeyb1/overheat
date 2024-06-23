Deferred_ECS_Op_Type :: enum {
    DESTROY;
    SPAWN;
    REMOVE_COMPONENT;
}

Deferred_ECS_Operation :: struct {
    type: Deferred_ECS_Op_Type;
    entity: Entity;

    // used for component add/remove operations
    type_id: Component_Type_ID;
}

process_deferred_operations :: (world: *World) {
    assert(world.should_defer == false);

    for world.deferred_ops {
        if it.type == {
            case .DESTROY;
                destroy_entity(world, it.entity);
            case .SPAWN;
                // It's possible that the entity was destoyed in the staging world before we could copy it to the main world, very unlikely though
                if is_entity_valid(world, it.entity) {
                    copy_entity_between_deferred(world, it.entity);
                }
            case .REMOVE_COMPONENT;
                // it's possible that the entity was destroyed before component removal was queued
                // do nothing in this case.
                if is_entity_valid(world, it.entity) {
                    remove_component(world, it.entity, it.type_id);
                }
            case;
                assert(false, "Not yet implemented");
        }
    }
    world.deferred_ops.count = 0;
}

#scope_file 

copy_entity_between_deferred :: (world: *World, source: Entity) -> Entity {

    source_stage: *Stage;
    dest_stage: *Stage;
    if source.deferred {
        source_stage = *world.deferred_stage;
        dest_stage = *world.stage;
    } else {
        source_stage = *world.stage;
        dest_stage = *world.deferred_stage;
    }

    s_record := table_find_pointer(*source_stage.entity_records, source.raw);
    assert(s_record != null);

    from := *source_stage.archetypes[s_record.archetype_id];

    new := add_entity(*world.stage, from.type_ids);

    d_record := table_find_pointer(*dest_stage.entity_records, new.raw);
    assert(d_record != null);

    to := *dest_stage.archetypes[d_record.archetype_id];

    for ctid : from.type_ids {
        src_component, src_size := get_component(from, s_record.row, ctid);
        dst_component, dst_size := get_component(to, d_record.row, ctid);
        assert(src_size == dst_size);

        memcpy(dst_component, src_component, src_size);
    }

    return new;
}