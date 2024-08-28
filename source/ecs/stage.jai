Stage :: struct {
    world: *World;

    entities: [..] Entity;

    entity_records: Table(s64, Entity_Record);

    free_indices: [..] s32;

    archetypes: [..] Archetype;

    archetype_cache: Table([] s64, [..] s64, given_compare_function=compare_cids);
}

Entity_Record :: struct {
    archetype_id: s64;
    row: s64;
}

entity_is_alive :: (using stage: Stage, entity: Entity) -> bool {
    if entity.index == INVALID_ENTITY_INDEX then return false;
    if entity.index >= stage.entities.count then return false;
    if entities[entity.index].index == INVALID_ENTITY_INDEX then return false;
    if entity.generation != entities[entity.index].generation then return false;
    return true;
}

entity_init :: (using stage: *Stage, entity: Entity, components: [] s64) {
    assert(entity.index != INVALID_ENTITY_INDEX);

    archetype, archetype_id := archetype_get_or_create(stage, components);
    row := archetype_entity_add(archetype, entity);

    table_add(*entity_records, entity.raw, .{ archetype_id = archetype_id, row = row });

    // the new entity is the only entity in the archetype, it is now active:
    if archetype.entities.count == 1 {
        archetype_cache_add(stage, archetype);
    }
}

entity_create :: (using stage: *Stage, components: [] s64) -> Entity {
    new_entity: *Entity;
    if free_indices.count > 0 {
        index := pop(*free_indices);
        new_entity = *entities[index];
        
        // dead entities are marked with a -1 index, we should not be reusing the index unless it's -1
        assert(new_entity.index == -1);
        new_entity.index = index;
        // generation count is already incremented on deletion, so we dont increment it here.
    } else {
        new_entity = array_add(*entities);
        new_entity.generation = 0;
        new_entity.index = cast(s32) entities.count-1;
    }

    entity_init(stage, new_entity, components);

    return new_entity.*;
}

entity_make :: (using stage: *Stage, entity: Entity, components: [] s64) -> Entity {
    assert(entity.index >= entities.count || entities[entity.index].index == -1);

    if entity.index >= entities.count {
        // start creating a bunch of entities and add them to the free indices to ensure the entity list is allocated
        // up until the new entity index.
        new_entities_start := entities.count;

        array_resize(*entities, entity.index + 1);
        for new_entities_start..(cast(s64)entity.index){
            if it == entity.index then continue;

            entities[it].index = -1;
            array_add(*free_indices, cast(s32) it);
        }
    } else {
        assert(entities[entity.index].index == -1);
        removed := array_unordered_remove_by_value(*free_indices, entity.index, stop_after_first=true);
        assert(removed == 1);
    }

    entities[entity.index].index = entity.index;

    entity_init(stage, entity, components);

    return entity;
}

stage_entity_mark_unused :: (using stage: *Stage, entity: Entity) {
    assert(entity_is_alive(stage, entity));

    entities[entity.index].index = INVALID_ENTITY_INDEX;
    entities[entity.index].generation += 1;

    table_remove(*entity_records, entity.raw);
    array_add(*free_indices, entity.index);
}

stage_entity_delete :: (using stage: *Stage, entity: Entity) {
    record := entity_record_get_ptr(stage, entity);
    assert(record != null);

    assert(record.archetype_id < archetypes.count);
    archetype := *archetypes[record.archetype_id];
    if archetype.entities.count > 1 {
        entity_to_swap := archetype.entities[archetype.entities.count-1];
        swap_record := entity_record_get_ptr(stage, entity_to_swap);
        assert(swap_record != null && swap_record.row == archetype.entities.count-1);
        swap_record.row = record.row;
    }

    array_unordered_remove_by_index(*archetype.entities, record.row);
    for * archetype.storage {
        ecs_storage_row_remove(it, record.row);
        assert(it.count == archetype.entities.count);
    }
    
    if archetype.entities.count == 0 {
        archetype_cache_remove(stage, archetype.id);
    }
    
    stage_entity_mark_unused(stage, entity);
}

stage_entity_get_types :: (using stage: *Stage, entity: Entity) -> [] s64 {
    record, success := entity_record_get(stage, entity);
    assert(success);

    return archetypes[record.archetype_id].type_ids;
}

entity_record_get_ptr :: (using stage: Stage, entity: Entity) -> *Entity_Record {
    return table_find_pointer(*entity_records, entity.raw);
}

entity_record_get :: (using stage: Stage, entity: Entity) -> Entity_Record, bool #must {
    record, success := table_find(*entity_records, entity.raw);
    return record, success;
}

entity_archetype_get :: (using stage: Stage, entity: Entity) -> *Archetype {
    record, success := entity_record_get(stage, entity);
    assert(success);
    return *archetypes[record.archetype_id];
}

stage_component_get :: (using stage: Stage, entity: Entity, cid: s64) -> *void {
    record, success := entity_record_get(stage, entity);
    assert(success);

    archetype := *stage.archetypes[record.archetype_id];
    return archetype_component_get(archetype, record.row, cid);
}

stage_component_add :: (using stage: *Stage, entity: Entity, cid: s64) -> *void {
    assert(entity_is_alive(stage, entity));

    record := entity_record_get_ptr(stage, entity);
    assert(record != null);

    from_arch := entity_archetype_get(stage, entity);
    to_arch := archetype_plus(stage, from_arch.type_ids, cid);
    // archetype_plus may have caused the archetypes array to resize, thereby invalidating our pointer. reset it just in case:
    from_arch = entity_archetype_get(stage, entity);

    entity_storage_move(stage, to_arch, from_arch, entity);

    result := stage_component_get(stage, entity, cid);
    assert(result != null);
    return result;
}

stage_component_remove :: (using stage: *Stage, entity: Entity, cid: s64) -> bool {
    assert(entity_is_alive(stage, entity));

    record := entity_record_get_ptr(stage, entity);
    assert(record != null);
    if !record then return false;

    from_arch := entity_archetype_get(stage, entity);
    to_arch := archetype_minus(stage, from_arch.type_ids, cid);
    // archetype_minus may have caused the archetypes array to resize, thereby invalidating our pointer. reset it just in case:
    from_arch = entity_archetype_get(stage, entity);

    entity_storage_move(stage, to_arch, from_arch, entity);

    return true;
}

entity_storage_move :: (from_stage: *Stage, to_arch: *Archetype, from_arch: *Archetype, entity: Entity) {
    entity_storage_move(from_stage, from_stage, to_arch, from_arch, entity);
}

entity_storage_move :: (from_stage: *Stage, to_stage: *Stage, to_arch: *Archetype, from_arch: *Archetype, entity: Entity) {
    from_record := entity_record_get_ptr(from_stage, entity);
    assert(from_record != null);

    source_row := from_record.row;

    dest_row := archetype_entity_add(to_arch, entity);

    cids_to_copy := ifx from_arch.type_ids.count > to_arch.type_ids.count then to_arch.type_ids else from_arch.type_ids;

    for cid : cids_to_copy {
        src_component, src_size := archetype_component_get(from_arch, source_row, cid);
        dst_component, dst_size := archetype_component_get(to_arch, dest_row, cid);
        assert(src_size == dst_size);

        memcpy(dst_component, src_component, src_size);
    }

    array_unordered_remove_by_index(*from_arch.entities, source_row);

    to_record := entity_record_get_ptr(to_stage, entity);
    to_record.row = dest_row;
    to_record.archetype_id = to_arch.id;
}

archetype_get_or_create :: (using stage: *Stage, cids: [] s64) -> *Archetype, s64 {
    for * archetypes {
        if archetype_types_equal(it, cids) {
            return it, it_index;
        }
    }

    result := array_add(*archetypes);
    arch_id := archetypes.count-1;
    archetype_init(result, stage.world, cids, arch_id);

    return result, arch_id;
}

archetype_plus :: (using stage: *Stage, cids: [] s64, plus: s64) -> *Archetype {
    new_types: [..] s64;
    new_types.allocator = temp;
    array_copy(*new_types, cids);
    array_add(*new_types, plus);
    quick_sort(new_types, (x) => x);

    return archetype_get_or_create(stage, new_types);
}

archetype_minus :: (using stage: *Stage, cids: [] s64, minus: s64) -> *Archetype {
    new_types: [..] s64;
    new_types.allocator = temp;
    array_copy(*new_types, cids);
    array_ordered_remove_by_value(*new_types, minus);

    return archetype_get_or_create(stage, new_types);
}

archetype_cache_add :: (using stage: *Stage, archetype: *Archetype) {
    for * archetype_cache {
        cid_cache := it_index;
        arch_ids := it;

        if archetype_types_match(archetype, cid_cache) {
            array_add_if_unique(arch_ids, archetype.id);
        }
    }
}

archetype_cache_remove :: (using stage: *Stage, arch_id: s64) {
    for * archetype_cache {
        arch_ids := it;

        array_unordered_remove_by_value(arch_ids, arch_id, stop_after_first=true);
    }
}

archetype_cache_find_or_create :: (using stage: *Stage, cids: [] s64) -> [] s64 {
    result := table_find_pointer(*archetype_cache, cids);
    if result != null then return result.*;

    _archetypes: [..] s64;
    result = table_add(*archetype_cache, array_copy(cids), _archetypes);

    for * archetypes {
        if archetype_types_match(it, cids) && it.entities.count > 0 {
            array_add(result, it_index);
        }
    }

    return result.*;
}

stage_bootstrap :: (using stage: *Stage) {
    carch := array_add(*archetypes);
    carch.id = archetypes.count-1;

    storage := array_add(*carch.storage);
    storage.component_size = type_info(ECS_Component).runtime_size;
    storage.initializer = type_info(ECS_Component).initializer;

    array_add(*carch.type_ids, cid_get(stage.world, ECS_Component));
}

#import "Basic";