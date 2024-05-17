Entity :: union {
    struct {
        index: s32;
        generation: s32;
    }
    raw: s64;
}

INVALID_ENTITY_INDEX : s32 : -1;

operator == :: (a: Entity, b: Entity) -> bool {
    return a.raw == b.raw;
}

#poke_name Basic operator==;
