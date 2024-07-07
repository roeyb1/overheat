Stage :: struct {
    /** A list of all currently alive entities */
    entities: [..] Entity;
    free_entity_indices: [..] s32;

    /** Maps an entity to it's archetype index */
    entity_records: Table(s64, Entity_Record);

    archetypes: [..] Archetype;

    /** Caches the results of trying to find all archetypes with a subset of components */
    archetype_cache: Table([] Component_Type_ID, [..] s64, given_compare_function=compare_ctids);
}

Entity_Record :: struct {
    archetype_id: s64;
    row: s64;
}

is_valid :: (stage: *Stage, entity: Entity) -> bool {
    if entity.index == INVALID_ENTITY_INDEX then return false;
    if entity.index >= stage.entities.count then return false;
    if entity.generation != stage.entities[entity.index].generation then return false;
    return true;
}

add_entity :: (stage: *Stage, ctids: [] Component_Type_ID) -> Entity {
    new_entity: *Entity;
    if stage.free_entity_indices.count > 0 {
        index := pop(*stage.free_entity_indices);
        new_entity = *stage.entities[index];

        << new_entity = .{index = index, generation = stage.entities[index].generation};
    } else {
        new_entity = array_add(*stage.entities);
        new_entity.generation = 0;
        new_entity.index = cast(s32) stage.entities.count-1;
    }

    assert(new_entity.index != INVALID_ENTITY_INDEX);

    archetype, archetype_id := get_or_create_archetype(stage, ctids);
    row := add_entity(archetype, new_entity);

    table_add(*stage.entity_records, new_entity.raw, .{archetype_id = archetype_id, row = row});

    if archetype.entities.count == 1 {
        add_archetype_to_active_cache(stage, archetype, archetype_id);
    }

    return new_entity;
}

remove_entity :: (stage: *Stage, entity: Entity) {
    old_record, success := table_find(*stage.entity_records, entity.raw);
    if !success then return;

    // increment the generation number so we can check old entity indexes against it to see if it was destroyed.
    stage.entities[entity.index].generation += 1;
    stage.entities[entity.index].index = INVALID_ENTITY_INDEX;

    remove_entity(*stage.archetypes[old_record.archetype_id], old_record.row, *stage.entity_records);
    if stage.archetypes[old_record.archetype_id].entities.count == 0 {
        remove_archetype_from_active_cache(stage, old_record.archetype_id);
    }

    table_remove(*stage.entity_records, entity.raw);

    array_add(*stage.free_entity_indices, entity.index);
}

get_component :: (stage: *Stage, entity: Entity, ctid: Component_Type_ID) -> *void {
    record, success := table_find(*stage.entity_records, entity.raw);
    if !success then return null;

    return get_component(*stage.archetypes[record.archetype_id], record.row, ctid);
}

has_components :: (stage: *Stage, entity: Entity, ctids: [] Component_Type_ID) -> bool {
    record, success := table_find(*stage.entity_records, entity.raw);
    if !success then return false;

    return archetype_contains_types(*stage.archetypes[record.archetype_id], ctids);
}

get_component_types :: (stage: *Stage, entity: Entity) -> [] Component_Type_ID {
    record, success := table_find(*stage.entity_records, entity.raw);
    assert(success);
    return stage.archetypes[record.archetype_id].type_ids;
}

add_component :: (stage: *Stage, entity: Entity, add_ctid: Component_Type_ID) -> *void {
    record := table_find_pointer(*stage.entity_records, entity.raw);
    assert(record != null);
    if record == null then return null;

    from := *stage.archetypes[record.archetype_id];
    to, to_id := archetype_plus(stage, from.type_ids, add_ctid);
    // archetype_plus may have caused the archetypes array to resize, thereby invalidating our pointer. reset it just in case:
    from = *stage.archetypes[record.archetype_id];

    new_row := move_entity(to, from, record.row, entity, *stage.entity_records);
    if from.entities.count == 0 {
        remove_archetype_from_active_cache(stage, record.archetype_id);
    }
    if to.entities.count == 1 {
        add_archetype_to_active_cache(stage, to, to_id);
    }

    record.row = new_row;
    record.archetype_id = to_id;

    result := get_component(to, record.row, add_ctid);

    return result;
}

remove_component :: (stage: *Stage, entity: Entity, remove_ctid: Component_Type_ID) -> bool {
    record := table_find_pointer(*stage.entity_records, entity.raw);
    assert(record != null);
    if record == null then return false;

    from := *stage.archetypes[record.archetype_id];

    if !has_component_type(from, remove_ctid) {
        return false;
    }

    to, to_id := archetype_minus(stage, from.type_ids, remove_ctid);
    // archetype_minus may have caused the archetypes array to resize, thereby invalidating our pointer. reset it just in case:
    from = *stage.archetypes[record.archetype_id];

    new_row := move_entity(to, from, record.row, entity, *stage.entity_records);
    if from.entities.count == 0 {
        remove_archetype_from_active_cache(stage, record.archetype_id);
    }
    if to.entities.count == 1 {
        add_archetype_to_active_cache(stage, to, to_id);
    }

    record.row = new_row;
    record.archetype_id = to_id;
    return true;
}

archetype_plus :: (stage: *Stage, ctids: [] Component_Type_ID, plus: Component_Type_ID) -> (*Archetype, s64) {
    new_types: [..] Component_Type_ID;
    new_types.allocator = temp;
    array_copy(*new_types, ctids);
    array_add(*new_types, plus);
    quick_sort(new_types, (x) => x.unique_id);

    archetype, id := get_or_create_archetype(stage, new_types);
    return archetype, id;
}

archetype_minus :: (stage: *Stage, ctids: [] Component_Type_ID, minus: Component_Type_ID) -> (*Archetype, s64) {
    new_types: [..] Component_Type_ID;
    new_types.allocator = temp;
    array_copy(*new_types, ctids);

    // ordered remove by value
    {
        for new_types if it == minus { array_ordered_remove_by_index(*new_types, it_index); break; };
    }

    archetype, id := get_or_create_archetype(stage, new_types);
    return archetype, id;
}

get_or_create_archetype :: (stage: *Stage, ctids: [] Component_Type_ID) -> (*Archetype, s64) {
    for * stage.archetypes {
        if archetype_matches_types(it, ctids) {
            return it, it_index;
        }
    }

    result := array_add(*stage.archetypes);
    archetype_id := stage.archetypes.count-1;

    init(result, ctids, archetype_id);

    add_archetype_to_active_cache(stage, result, archetype_id);

    return result, archetype_id;
}

add_archetype_to_active_cache :: (stage: *Stage, archetype: *Archetype, archetype_id: s64) {
    for * stage.archetype_cache {
        cached_ctids: [] Component_Type_ID = it_index;
        cached_archetype_ids: *[..] s64 = it;

        // if this archetype would match the ctids in this cache entry, add it to the cache now:
        if archetype_contains_types(archetype, cached_ctids) {
            array_add_if_unique(cached_archetype_ids, archetype_id);
        }
    }

}

remove_archetype_from_active_cache :: (stage: *Stage, archetype_id: s64) {
    for * stage.archetype_cache {
        cached_archetype_ids: *[..] s64 = it;

        array_unordered_remove_by_value(cached_archetype_ids, archetype_id, stop_after_first=true);
    }
}

find_or_create_cached_archetypes_for_ctids :: (stage: *Stage, ctids: [] Component_Type_ID) -> [] s64 {
    result := table_find_pointer(*stage.archetype_cache, ctids);
    if result != null then return << result;

    archetypes: [..] s64;
    result = table_add(*stage.archetype_cache, array_copy(ctids), archetypes);
    for * stage.archetypes {
        if archetype_contains_types(it, ctids) && it.entities.count > 0 then array_add(result, it_index);
    }
    return << result;
}
