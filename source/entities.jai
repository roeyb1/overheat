EntityId :: #type,isa s64;
INVALID_EID :: -1;

Entity :: struct {
    entity_type: Type;
    locator: Bucket_Locator;
    data: *void;
    name: string;

    id: EntityId;

    position: Vector2;
    prev_position: Vector2;
    velocity: Vector2;

    bounds: AABB;
}

Player :: struct {
    #as using entity: *Entity;

    networking_id: u64;

    sprite: Sprite;

    anim_statemachine: Player_Anim_State_Machine;

    is_attacking: bool;

    stats_component: Player_Stats_Component;
}

EntityCast :: (entity: *Entity, $type: Type) -> *type {
    assert(entity.entity_type == type, "Invalid cast: Attempted to cast entity of type % to type %!", entity.entity_type, type);

    return cast(*type) entity.data;
}


init_local_player :: (networking_id: u64) -> *Player {
    player := make_entity(*g_world, Player, tprint("Player_%",networking_id));
    player.networking_id = networking_id;

    sprite := g_local_player_sprite;
    
    player.sprite = Sprite.{sprite, .{1.5, 1.5}, 0, 1};
    make_anim_sm_player(player);

    init_player_stats(*player.stats_component,DEFAULT_PLAYER_STATS);
    

    return player;
}

init_remote_player :: (networking_id: u64, player_position: Vector2) -> *Player {
    player := make_entity(*g_world, Player, tprint("Player_%", networking_id));
    player.networking_id = networking_id;
    player.position = player_position;

    sprite := g_player_sprite;

    player.sprite = Sprite.{sprite, .{1.5, 1.5}, 0, 1};
    make_anim_sm_player(player);

    init_player_stats(*player.stats_component,DEFAULT_PLAYER_STATS);

    return player;
}

#load "math.jai";