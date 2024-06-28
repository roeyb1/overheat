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
            if !is_valid(q.world, followers[it].entity) then continue;

            target_pos_component := get_component(q.world, followers[it].entity, Position);
            assert(target_pos_component != null, "Attempting to follow an entity that doesn't have a position component!");
            target_pos = target_pos_component.value;
        } else {
            entity, found := find_nearest_with_tag(q.world, positions[it], q.entities[it], followers[it].tag);

            if found {
                target_pos_component := get_component(q.world, entity, Position);
                assert(target_pos_component != null, "Attempting to follow an entity that doesn't have a position component!");
                target_pos = target_pos_component.value;
            }
        }

        direction := target_pos - positions[it];
        if length(direction) <= followers[it].max_distance {
            velocities[it].value = unit_vector(direction) * move_speeds[it].value;
        } else {
            velocities[it].value = .{0, 0};
        }
    }
} @System(PreUpdate) @Write(Velocity) @Read(Follow,Move_Speed,Position,Collision_Spatial)

#scope_file

find_nearest_with_tag :: (world: *World, point: Vector2, self: Entity, ctid: Component_Type_ID) -> Entity, bool {
    // @Speed accelerate with AABB tree
    candidates: [..] Entity;
    candidates.allocator = temp;
    distances: [..] float;
    distances.allocator = temp;


    for q : make_iter_raw(world, Component_Type_ID.[#run component_type_id(Position), ctid]) {
        positions := query_get(q, Position);

        array_append(*candidates, q.entities);
        for 0..q.count-1 {
            array_add(*distances, length(point - positions[it]));
        }
    }
    
    if distances.count == 0 {
        return INVALID_ENTITY, false;
    }

    min_index := 0;
    for 0..distances.count-1 {
        if distances[it] < distances[min_index] then min_index = it;
    }
    return candidates[min_index], true;
}