EcsComponent :: struct @Component {
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

Ecs_Wildcard : s32 : S32_MAX;

cid_from_entity :: inline (entity: Entity) -> s64 {
    return entity.raw;
}

cid_get :: (using world: *World, type: Type) -> s64 {
    assert((cast(*Type_Info)type).type == .STRUCT);

    ti := cast(*Type_Info_Struct)type;
    
    cid, success := table_find(*cid_map, ti.name);
    assert(success, "Failed to find CID for type: %", ti.name);

    return cid;
}

cid_low :: inline (cid: s64) -> s32 {
    return cast,no_check(s32) cid;
}

cid_high :: inline (cid: s64) -> s32 {
    return cast,no_check(s32) (cid >> 32);
}

cid_match :: (a: s64, b: s64) -> bool {
    match :: inline (a: s32, b: s32) -> bool {
        if a == Ecs_Wildcard || b == Ecs_Wildcard {
            return true;
        }

        return (a == b);
    }

    // compare the low and high bits separately. if either matches a wildcard, we consider it matching:
    a_lo: s32 = cid_low(a);
    a_hi: s32 = cid_high(a);

    b_lo: s32 = cid_low(b);
    b_hi: s32 = cid_high(b);

    return match(a_lo, b_lo) && match(a_hi, b_hi);
}

get_component_type_info :: (type: Type) -> Component_Type_Info {
    cti: Component_Type_Info;
    cti.ti = cast(*Type_Info_Struct)type;

    if has_note(cti.ti, "SingletonComponent") then cti.is_singleton = true;
    if has_note(cti.ti, "Tag") then cti.is_tag = true;
    if has_note(cti.ti, "Pair") then cti.is_pair = true;

    return cti;
}

cid_register :: (using world: *World, type: Type) {
    cent := entity_spawn(world);

    cid := cid_from_entity(cent);

    ci := ecs_add(world, cent, EcsComponent);

    assert((cast(*Type_Info)type).type == .STRUCT);
    ti := cast(*Type_Info_Struct)type;

    ci.runtime_size = ti.runtime_size;

    table_add(*cid_map, ti.name, cid);

    cti := get_component_type_info(type);
    cti.cid = cid;
    table_add(*type_info_map, cid, cti);

    log_verbose("Registered CID %: %", ti.name, cid);

    if cti.is_singleton {
        ecs_add(world, cent, cid);
    }
}

cid_to_type_info :: (using world: *World, cid: s64) -> Component_Type_Info {
    result, success := table_find(*type_info_map, cast(s64) (cast,no_check(s32)cid));
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

cid_pair :: (using world: *World, type: Type, cid: s64) -> s64 {
    cid_low := cid_get(world, type);
    cid_high := cast(s32)cid;

    result: Entity;
    result.index = cast(s32) cid_low;
    result.generation = cast(s32) cid_high;

    return result.raw;
}

cid_pair :: inline (using world: *World, type: Type, entity: Entity) -> s64 {
    return cid_pair(world, type, cast(s64) entity.index);
}

entity_from_cid :: inline (cid: s64) -> Entity {
    assert(cid != NULL_COMPONENT_ID);
    return .{ index = cast,no_check(s32) cid };
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