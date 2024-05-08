EntityId :: #type,isa s64;
INVALID_EID :: -1;

Entity :: struct {
    entity_type: Type;
    locator: Bucket_Locator;
    data: *void;
    name: string;

    id: EntityId;

    position: Vector2;
    velocity: Vector2;

    bounds: AABB;
}

EntityCast :: (entity: *Entity, $type: Type) -> *type {
    assert(entity.entity_type == type, "Invalid cast: Attempted to cast entity of type % to type %!", entity.entity_type, type);

    return cast(*type) entity.data;
}

#load "math.jai";