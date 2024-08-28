Archetype :: struct {
    storage: [..] Component_Storage;

    type_ids: [..] s64;

    entities: [..] Entity;

    id: s64;
}

archetype_init :: (using archetype: *Archetype, world: *World, cids: [] s64, arch_id: s64) {
    for cid : cids {
        ci := ecs_get(world, entity_from_cid(cid), ECS_Component);
        cti := cid_to_type_info(world, cid);

        storage := array_add(*archetype.storage);
        storage.component_size = ci.runtime_size;
        storage.initializer = ifx cti.ti then cti.ti.initializer else null;

        array_add(*type_ids, cid);
    }

    array_reset(*archetype.entities);
    archetype.id = arch_id;
}

archetype_entity_add :: (using archetype: *Archetype, entity: Entity) -> s64 {
    for * storage {
        ecs_storage_row_add(it);
    }
    array_add(*entities, entity);
    return entities.count-1;
}

archetype_component_get :: (using archetype: *Archetype, row: s64, cid: s64) -> *void, s64 {
    for type_ids {
        if it == cid {
            return ecs_storage_row_get(storage[it_index], row), storage[it_index].component_size;
        }
    }
    return null, 0;
}

archetype_iter_get :: (using archetype: *Archetype, cid: s64) -> *void {
    for type_ids {
        if it == cid {
            return storage[it_index].data;
        }
    }
    return null;
}

archetype_types_equal :: (using archetype: *Archetype, cids: [] s64) -> bool {
    if type_ids.count != cids.count then return false;
    for 0..type_ids.count-1 {
        if type_ids[it] != cids[it] then return false;
    }
    return true;
}

archetype_types_match :: (using archetype: *Archetype, cids: [] s64) -> bool {
    for cid : cids {
        if !archetype_types_contains(archetype, cid) then return false;
    }
    return true;
}
archetype_types_contains :: (using archetype: *Archetype, cid: s64) -> bool {
    for archetype.type_ids {
        if it == cid then return true;
        if it > cid then return false;
    }
    return false;
}