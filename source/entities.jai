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

    stats_component: Player_Stats_Component;
}

EntityCast :: (entity: *Entity, $type: Type) -> *type {
    assert(entity.entity_type == type, "Invalid cast: Attempted to cast entity of type % to type %!", entity.entity_type, type);

    return cast(*type) entity.data;
}

//requires better system for assigning sprites
init_player :: (player: *Player){
    sprite: *SpriteSheet;
    if player == g_local_player sprite = g_local_player_sprite;
    else sprite = g_player_sprite;

    player.sprite = Sprite.{sprite, .{1.5, 1.5}, 0, 1};
    init_player_stats(*player.stats_component,DEFAULT_OVERHEAT_STATS);
}

#load "math.jai";