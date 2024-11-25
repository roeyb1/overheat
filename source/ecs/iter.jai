ECS_Iter :: struct {
    world: *World;
    archetype_ids: [] s64; // archetype indices that match the terms
}

ECS_Iter_Op :: enum {
    AND;
    OR;
    NOT;
}

ECS_Iter_Term :: struct {
    cid: s64;
    op: ECS_Iter_Op = .AND;
}

ecs_iter_term :: (world: *World, type: Type, op: ECS_Iter_Op = .AND) -> ECS_Iter_Term {
    return .{cid = cid_get(world, type), op = op};
}

iter_make_uncached :: (world: *World, terms: ..ECS_Iter_Term) -> ECS_Iter {
    iter: ECS_Iter;
    iter.world = world;
    iter.archetype_ids = archetype_cache_match_terms(world, terms);
    return iter;
}

iter_make_raw :: (world: *World, cids: [] s64) -> ECS_Iter {
    iter: ECS_Iter;
    iter.world = world;
    iter.archetype_ids = archetype_cache_find_or_create(*world.stage, cids);
    return iter;
}

iter_make :: (world: *World) -> ECS_Iter {
    return iter_make_raw(world, .[]);
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
    iter.archetype_ids = archetype_cache_find_or_create(*world.stage, cids);

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

#scope_file

archetype_cache_match_terms :: (world: *World, terms: [] ECS_Iter_Term) -> [] s64 {
    archetypes: [..] s64;
    archetypes.allocator = temp;

    // start with all the AND terms and then we filter down based on the optionals:
    and_terms: [..] s64;
    and_terms.allocator = temp;
    not_terms: [..] s64;
    not_terms.allocator = temp;

    for term : terms {
        if term.op == .AND {
            array_add(*and_terms, term.cid);
        }
        else if term.op == .NOT {
            array_add(*not_terms, term.cid);
        }
    }

    // collect the archetypes that match our AND terms and have entities:
    for * world.stage.archetypes {
        if archetype_types_match(it, and_terms) && it.entities.count > 0 {
            array_add(*archetypes, it_index);
        }
    }

    // filter out archetypes that have any of our NOT terms:
    for not_term : not_terms {
        for arch_id : archetypes {
            if archetype_type_match(*world.stage.archetypes[arch_id], not_term) then remove arch_id;
        }
    }

    // remove any archetypes that don't contain at least a single term from an or chain:
    {
        or_chain: [..] s64;
        or_chain.allocator = temp;
        started_chain := false;
        for term : terms {
            if term.op == .OR {
                if !started_chain {
                    started_chain = true;
                    array_reset_keeping_memory(*or_chain);
                }

                array_add(*or_chain, term.cid);
            }

            if term.op != .OR {
                started_chain = false;
                if or_chain.count > 1 {
                    for arch_id : archetypes {
                        has_one := false;
                        for or_term : or_chain {
                            if archetype_type_match(*world.stage.archetypes[arch_id], or_term) {
                                has_one = true;
                                break;
                            }
                        }

                        if !has_one then remove arch_id;
                    }
                }
            }
        }
        if started_chain {
            for arch_id : archetypes {

                has_one := false;
                for or_term : or_chain {
                    if archetype_type_match(*world.stage.archetypes[arch_id], or_term) {
                        has_one = true;
                        break;
                    }
                }

                if !has_one then remove arch_id;
            }
        }
    }

    return archetypes;
}