Entity :: struct {
    index: s32 = INVALID_ENTITY_INDEX;
    generation: s32;

    #place index;
    raw: s64 = -1;
}

INVALID_ENTITY_INDEX : s32 : -1;
INVALID_ENTITY :: Entity.{index = INVALID_ENTITY_INDEX, generation = 0 };

operator == :: (a: Entity, b: Entity) -> bool {
    return a.raw == b.raw;
}

compare_entities :: (a: Entity, b: Entity) -> bool {
    return a.raw == b.raw;
}

entity_from_raw :: inline (raw: s64) -> Entity {
    return .{ raw = raw };
}

#poke_name Basic operator==;