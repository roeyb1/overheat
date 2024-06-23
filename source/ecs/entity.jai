Entity :: struct {
    index: s32 = INVALID_ENTITY_INDEX;
    generation: s32;

#place index;
    raw: s64 = -1;

    deferred: bool = false;
}

INVALID_ENTITY_INDEX : s32 : -1;

operator == :: (a: Entity, b: Entity) -> bool {
    return a.raw == b.raw;
}

#poke_name Basic operator==;
