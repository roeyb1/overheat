Query :: struct {
    world: *World;

    entities: [] Entity;
    types: [] Component_Type_ID;
    
    current_archetype: *Archetype;

    count: s64;
}

query_get :: (query: Query, $type: Type) -> [] type {
    result: [] type;
    result.data = get_iter(query.current_archetype, #run component_type_id(type));
    result.count = query.entities.count;
    return result;
}
