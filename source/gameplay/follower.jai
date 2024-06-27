Follow :: struct @Component {
    Follow_Mode :: enum u8 {
        ENTITY;
        TAG;
    }

    mode: Follow_Mode;

    union {
        entity: Entity;
        tag: Component_Type_ID;
    };

    max_distance: float;
}

Follower :: struct @Bundle {
    move_speed: Move_Speed;
    follow: Follow;
}

follow_entity :: (q: Query) {
    velocities := query_get(q, Velocity);
    move_speeds := query_get(q, Move_Speed);
    positions := query_get(q, Position);
    followers := query_get(q, Follow);

    for 0..q.count-1 {
        target_pos := Vector2.{0, 0};

        if followers[it].mode == .ENTITY {
            if !is_entity_valid(q.world, followers[it].entity) then continue;

            target_pos_component := get_component(q.world, followers[it].entity, Position);
            assert(target_pos_component != null, "Attempting to follow an entity that doesn't have a position component!");
            target_pos = target_pos_component.value;
        } else {
            Params :: struct {
                world: *World;
                type: Component_Type_ID;
            }
            params := Params.{q.world, followers[it].tag};

            entity, found := find_nearest_matching_predicate(get_singleton(q.world, Collision_Spatial), positions[it], q.entities[it], (entity: Entity, data: *void) -> bool {
                params := cast(*Params) data;
                return has_component(params.world, entity, params.type);
            }, *params);

            if found {
                target_pos_component := get_component(q.world, entity, Position);
                assert(target_pos_component != null, "Attempting to follow an entity that doesn't have a position component!");
                target_pos = target_pos_component.value;
            }
        }

        direction := target_pos - positions[it];
        if length(direction) <= followers[it].max_distance {
            velocities[it].value = unit_vector(direction) * move_speeds[it].speed;
        } else {
            velocities[it].value = .{0, 0};
        }
    }
} @System(PreUpdate) @Write(Velocity) @Read(Follow,Move_Speed,Position,Collision_Spatial)