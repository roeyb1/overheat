Archetype :: struct {
    storage: [..] Component_Container;

    /* list of the type ids in this archetype. Additionally, the index of a type in this list is also the index that maps to the container for the type */
    type_ids: [..] Component_Type_ID;

    entities: [..] Entity;
}

init :: (archetype: *Archetype, ctids: [] Component_Type_ID) {
    for ctid : ctids {
        storage := array_add(*archetype.storage);
        storage.component_size = ctid.runtime_size;
        array_add(*archetype.type_ids, ctid);
    }
    array_reset(*archetype.entities);
}

archetype_matches_types :: (archetype: *Archetype, ctids: [] Component_Type_ID) -> bool {
    if archetype.type_ids.count != ctids.count then return false;
    // type arrays are always sorted, so we can simply check each element with it's pair
    for 0..archetype.type_ids.count-1 {
        if archetype.type_ids[it] != ctids[it] then return false;
    }
    return true;
}

/** Returns true of the archetype contains all of the types (it may also have others, but it at least has the subset) */
archetype_contains_types :: (archetype: *Archetype, ctids: [] Component_Type_ID) -> bool {
    for ctid : ctids {
        found := false;
        for 0..archetype.type_ids.count-1 {
            if archetype.type_ids[it] == ctid {
                found = true;
                break;
            }
        }
        if !found then return false;
    }
    return true;
}

get_iter :: (archetype: *Archetype, ctid: Component_Type_ID) -> *void {
    for archetype.type_ids {
        if it == ctid {
            return archetype.storage[it_index].data;
        }
    }
    assert(false);
    return null;
}

get_component :: (archetype: *Archetype, row: s64, ctid: Component_Type_ID) -> *void, s64 {
    for archetype.type_ids {
        if it == ctid {
            return get_component(*archetype.storage[it_index], row), archetype.storage[it_index].component_size;
        }
    }
    return null, 0;
}

add_entity :: (archetype: *Archetype, entity: Entity) -> s64 {
    for * archetype.storage {
        data := add_row(it);
        memset(data, 0, it.component_size);
    }
    array_add(*archetype.entities, entity);

    return archetype.entities.count-1;
}

remove_entity :: (archetype: *Archetype, row: s64, entity_records: *Table(s64, Entity_Record)) {
    array_unordered_remove_by_index(*archetype.entities, row);

    for * archetype.storage {
        remove_row(it, row);
        assert(it.count == archetype.entities.count);
    }

    swapped_row := archetype.entities.count;

    // the record for the element that got swapped into the removed entities place needs to be updated to reflect the new row:
    if swapped_row >= 0 {
        for * entity_records {
            record := it;
            if record.row == swapped_row {
                record.row = row;
                break;
            }
        }
    }
}

move_entity :: (dest: *Archetype, source: *Archetype, source_row: s64, entity: Entity, entity_records: *Table(s64, Entity_Record)) -> (dest_row: s64) {
    dest_row := add_entity(dest, entity);

    ctids_to_copy := ifx source.type_ids.count > dest.type_ids.count then dest.type_ids else source.type_ids;
    for ctid : ctids_to_copy {
        src_component, size := get_component(source, source_row, ctid);
        dst_component := get_component(dest, dest_row, ctid);

        memcpy(dst_component, src_component, size);
    }

    remove_entity(source, source_row, entity_records);

    return dest_row;
}

find_or_create_cached_archetypes_for_ctids :: (world: *World, ctids: [] Component_Type_ID) -> [] s64 {
    result := table_find_pointer(*world.archetype_cache, ctids);
    if result != null then return << result;

    archetypes: [..] s64;
    result = table_add(*world.archetype_cache, ctids, archetypes);
    for * world.archetypes {
        if archetype_contains_types(it, ctids) && it.entities.count > 0 then array_add(result, it_index);
    }
    return << result;
}
