Entity :: #type, isa s64;

INVALID_EID : Entity : 0;

next_entity_id: Entity = 1;

is_valid :: (entity: Entity) -> bool {
    return entity != INVALID_EID;
}


