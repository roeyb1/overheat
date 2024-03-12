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

Player :: struct {
    #as using entity: *Entity;

    player_id: u64;

    sprite: Sprite;

    status_component: Status_Component;
}

EntityCast :: (entity: *Entity, $type: Type) -> *type {
    assert(entity.entity_type == type, "Invalid cast: Attempted to cast entity of type % to type %!", entity.entity_type, type);

    return cast(*type) entity.data;
}

//requires better system for assigning sprites
initialize_player :: (player: *Player){
    sprite: *SpriteSheet;
    if player.id == 1 sprite = g_local_player_sprite;
    else sprite = g_player_sprite;

    player.sprite = Sprite.{sprite, .{1.5, 1.5}, 0, 1};
    initialize_status_component(*player.status_component,Player_Status_Component);
}

#load "math.jai";