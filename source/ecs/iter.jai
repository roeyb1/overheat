ECS_Iter :: struct {
    world: *World;
    archetype: [] s64; // component_types
    archetype_ids: [] s64; // archetype indices
}

iter_make_raw :: (world: *World, cids: [] s64) -> ECS_Iter {
    iter: ECS_Iter;
    iter.world = world;
    iter.archetype = cids;
    iter.archetype_ids = archetype_cache_find_or_create(*world.stage, iter.archetype);
    return iter;
}

iter_make :: (world: *World, types: ..Type) -> ECS_Iter {
    cids := cids_from_types(world, types);
    return iter_make_raw(world, cids);
}

iter_make :: (world: *World, cids: ..s64) -> ECS_Iter {
    return iter_make_raw(world, cids);
}

iter_make_uncached :: (world: *World, cids: ..s64) -> ECS_Iter {
    iter: ECS_Iter;
    iter.world = world;
    iter.archetype = cids;

    archetypes: [..] s64;
    archetypes.allocator = temp;
    for * world.stage.archetypes {
        if archetype_types_match(it, cids) && it.entities.count > 0 {
            array_add(*archetypes, it_index);
        }
    }
    iter.archetype_ids = archetypes;
    return iter;
}

iter_make_pair :: (world: *World, type: Type, entity: Entity, types: ..Type) -> ECS_Iter {
    cids := cids_from_types(world, types);
    array_add(*cids, cid_pair(world, type, entity));
    quick_sort(cids, (x) => x);

    iter: ECS_Iter;
    iter.world = world;
    iter.archetype = cids;
    iter.archetype_ids = archetype_cache_find_or_create(*world.stage, iter.archetype);

    return iter;
}

for_expansion :: (iter: ECS_Iter, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.

    query: Query;
    query.world = iter.world;

    #if flags & .POINTER == 0 {
        old_defer_value := query.world.is_deferring;
        query.world.is_deferring = true;
    }

    for arch_id, arch_index : iter.archetype_ids {
        archetype := *iter.world.stage.archetypes[arch_id];
        query.current_archetype = archetype;
        query.entities = archetype.entities;
        query.count = archetype.entities.count;

        `it := query;
        `it_index := arch_index;

        #insert body;
    }

    #if flags & .POINTER == 0 {
        query.world.is_deferring = old_defer_value;
        if !query.world.is_deferring {
            process_deferred_operations(query.world);
        }
    }
}