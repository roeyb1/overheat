ecs_add_bundle :: (using world: *World, entity: Entity, bundle: $T) {
    assert(false);
}

ecs_add_bundle :: (using world: *World, entity: Entity, type: Type) {
    assert(false);
}

entity_spawn_bundle :: (using world: *World, bundle: $T) -> Entity {
    assert(false);
    return INVALID_ENTITY;
}

entity_spawn_bundle :: (using world: *World, type: Type) -> Entity {
    assert(false);
    return INVALID_ENTITY;
}