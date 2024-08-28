ECS_Component :: struct @Component {
    runtime_size: s64 = 0;
}

Component_Type_Info :: struct {
    ti: *Type_Info_Struct;

    cid: s64;

    is_pair := false;
    is_tag := false;
    is_singleton := false;
}

NULL_COMPONENT_ID :: -1;

cid_from_entity :: inline (entity: Entity) -> s64 {
    return entity.raw;
}

cid_get :: (using world: *World, type: Type) -> s64 {
    assert((cast(*Type_Info)type).type == .STRUCT);

    ti := cast(*Type_Info_Struct)type;
    
    cid, success := table_find(*cid_map, ti.name);
    assert(success);

    return cid;
}

cid_register :: (using world: *World, type: Type) {
    cent := entity_spawn(world);

    ci := ecs_add(world, cent, ECS_Component);

    assert((cast(*Type_Info)type).type == .STRUCT);
    ti := cast(*Type_Info_Struct)type;

    ci.runtime_size = ti.runtime_size;

    cti: Component_Type_Info;
    cti.ti = ti;
    cti.cid = cent.raw;

    table_add(*cid_map, ti.name, cent.raw);
    table_add(*type_info_map, cent.raw, cti);
}

cid_to_type_info :: (using world: *World, cid: s64) -> Component_Type_Info {
    result, success := table_find(*type_info_map, cid);
    assert(success);
    return result;
}

cids_from_types :: (using world: *World, types: [] Type) -> [..] s64 {
    result: [..] s64;
    result.allocator = temp;

    for types {
        array_add(*result, cid_get(world, it));
    }

    quick_sort(result, (x) => x);

    return result;
}

cid_pair :: (using world: *World, type: Type, entity: Entity) -> s64 {
    cid_low := cid_get(world, type);
    cid_high := entity.index;

    result: Entity;
    result.index = cast(s32) cid_low;
    result.generation = cast(s32) cid_high;

    return result.raw;
}

entity_from_cid :: inline (cid: s64) -> Entity {
    assert(cid != NULL_COMPONENT_ID);
    return .{ raw = cid };
}

compare_cids :: (a: [] s64, b: [] s64) -> bool {
    if a.count != b.count then return false;
    // component type arrays are always sorted, so we can simply check each element with it's pair
    for 0..a.count-1 {
        if a[it] != b[it] then return false;
    }
    return true;
}

#placeholder ALL_COMPONENT_TYPES;