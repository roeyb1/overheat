Query :: struct {
    world: *World;

    entities: [] Entity;
    types: [] s64;
    
    current_archetype: *Archetype;

    count: s64;
}

query_get :: (using query: Query, $type: Type) -> [] type {
    result: [] type;
    result.data = archetype_iter_get(current_archetype, cid_get(world, type));
    result.count = entities.count;
    assert(result.data != null);
    return result;
}

query_get_opt :: (using query: Query, $type: Type) -> [] type {
    data := archetype_iter_get(current_archetype, cid_get(world, type));

    result: [] type;
    result.data = data;
    result.count = ifx data != null then entities.count else 0;
    return result;
}
