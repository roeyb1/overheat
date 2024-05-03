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

    networking_id: u64;

    sprite: Sprite;

    stats_component: Stats_Component;

    buff_component: BuffComponent;
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
    init_stats(*player.stats_component,DEFAULT_PLAYER_STATS);

    return player;
}

init_remote_player :: (networking_id: u64, player_position: Vector2) -> *Player {
    player := make_entity(*g_world, Player, tprint("Player_%", networking_id));
    player.networking_id = networking_id;
    player.position = player_position;

  
    sprite := g_player_sprite;

    player.sprite = Sprite.{sprite, .{1.5, 1.5}, 0, 1};
    init_stats(*player.stats_component,DEFAULT_PLAYER_STATS);

    return player;
}

update_buff_component :: (using player: *Player) {
    
    //transitory tick based buffs
    {   
        to_remove: [..] int;
        for *buff,i: buff_component.transitory_stat_per_tick {
            using buff;
            delta: float;

            duration = duration - g_delta_time;

            if duration < 0 {
                delta = g_delta_time + duration;
            }
            else {
                delta = g_delta_time;
            }

            apply_buff(*player.stats_component, buff, delta);
            if (buff.duration < 0){
                array_add(*to_remove,i);
            } 
        }

        for < index: to_remove {
            array_ordered_remove_by_index(*buff_component.transitory_stat_per_tick, index);
        }
    }

    
    //transitory constant buffs
    {
        to_remove: [..] int;
        for *buff,i: buff_component.transitory_stat_constant {
            using buff;
            delta: float;
            
            duration = duration - g_delta_time;

            if duration < 0 {
                delta = g_delta_time + duration;
            }
            else {
                delta = g_delta_time;
            }

            
            if (buff.duration < 0){
                array_add(*to_remove,i);
                remove_buff(*player.stats_component,buff);
            } 
        }

        for < index: to_remove {
            array_ordered_remove_by_index(*buff_component.transitory_stat_constant, index);
        }
    }
    
}

#load "math.jai";