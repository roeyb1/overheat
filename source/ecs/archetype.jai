Archetype :: struct {
    storage: [..] Component_Container;

    /* list of the type ids in this archetype. Additionally, the index of a type in this list is also the index that maps to the container for the type */
    type_ids: [..] Component_Type_ID;

    count: s64;
}

init :: (archetype: *Archetype, ctids: [] Component_Type_ID) {
    for ctid : ctids {
        storage := array_add(*archetype.storage);
        storage.component_size = ctid.runtime_size;
        array_add(*archetype.type_ids, ctid);
    }
}


archetype_matches_types :: (archetype: *Archetype, ctids: [] Component_Type_ID) -> bool {
    if archetype.type_ids.count != ctids.count then return false;
    // type arrays are always sorted, so we can simply check each element with it's pair
    for 0..archetype.type_ids.count-1 {
        if archetype.type_ids[it] != ctids[it] then return false;
    }
    return true;
}

get_component :: (archetype: *Archetype, row: s64, ctid: Component_Type_ID) -> *void, s64 {
    for archetype.type_ids {
        if it == ctid {
            return get_component(*archetype.storage[it_index], row), archetype.storage[it_index].component_size;
        }
    }
    return null, 0;
}

add_entity :: (archetype: *Archetype) -> s64 {
    for * archetype.storage {
        add_row(it);
    }

    archetype.count += 1;
    return archetype.count - 1;
}

remove_entity :: (archetype: *Archetype, row: s64) -> s64 {
    for * archetype.storage {
        remove_row(it, row);
    }

    archetype.count -= 1;
    return archetype.count-1;
}

move_entity :: (dest: *Archetype, source: *Archetype, source_row: s64) -> s64 {
    dest_row := add_entity(dest);

    ctids_to_copy := ifx source.type_ids.count > dest.type_ids.count then dest.type_ids else source.type_ids;
    for ctid : ctids_to_copy {
        src_component, size := get_component(source, source_row, ctid);
        dst_component := get_component(dest, dest_row, ctid);

        memcpy(dst_component, src_component, size);
    }

    remove_entity(source, source_row);

    return dest_row;
}
