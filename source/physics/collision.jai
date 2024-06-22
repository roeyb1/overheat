Collider_AABB :: struct @Component {
    #as using aabb: AABB;
}

Hit_Result :: struct {
    other: Entity;
    other_bounds: AABB;
}

Collision_Invoker :: struct @Component {
    /** List of all hit results which were generated against this entity this frame */
    hits_this_frame: [..] Hit_Result;
}

Collision_Spatial :: struct @SingletonComponent {
    // @Speed this will be optimized with an AABB tree
    bounds: [..] AABB;
    entities: [..] Entity;
}

build_collision_spatial :: (q: Query) {
    spatial := get_singleton(q.world, Collision_Spatial);

    colliders := query_get(q, Collider_AABB);
    positions := query_get(q, Position);

    // rebuild the spatial from scratch every frame.
    // #todo: only update the pieces that changed using events
    spatial.entities.count = 0;
    spatial.bounds.count = 0;

    array_append(*spatial.entities, q.entities);
    for 0..q.count-1 {
        array_add(*spatial.bounds, translate(colliders[it], positions[it]));
    }
} @System(OnValidate) @Write(Collision_Spatial) @Read(Position,Collider_AABB)

detect_collisions :: (q: Query) {
    invokers := query_get(q, Collision_Invoker);
    positions := query_get(q, Position);
    colliders := query_get(q, Collider_AABB);

    spatial := get_singleton(q.world, Collision_Spatial);

    for 0..q.count-1 {
        translated_aabb := translate(colliders[it], positions[it]);
        hits := find_hits_in_bounds(spatial, translated_aabb, q.entities[it]);

        array_append(*invokers[it].hits_this_frame, hits);
    }
} @System(OnValidate) @Write(Collision_Invoker) @Read(Position,Collider_AABB,Collision_Spatial)

resolve_collisions :: (q: Query) {
    invokers := query_get(q, Collision_Invoker);
    positions := query_get(q, Position);
    colliders := query_get(q, Collider_AABB);

    for 0..q.count-1 {
        for *hit : invokers[it].hits_this_frame {
            invoker_bounds := translate(colliders[it], positions[it]);

            minkowsky := minkowsky_difference(invoker_bounds, hit.other_bounds);
            // check if there even is still a collision. We may no longer be colliding due to the collision resolution of any previous hits.
            // We can do this by checking if the minkowsky diff still contains the origin:
            if is_inside(minkowsky, .{0, 0}) {
                penetration_vector := closest_point_on_aabb(minkowsky, .{0, 0});

                positions[it].value -= penetration_vector;
            }
        }
    }
} @System(PostUpdate) @Write(Position) @Read(Collision_Invoker,Collider_AABB)

/** Reset any hit results that might've been generated last frame. */
reset_collision_results :: (q: Query) {
    invokers := query_get(q, Collision_Invoker);

    for 0..q.count-1 {
        invokers[it].hits_this_frame.count = 0;
    }
} @System(PreUpdate) @Write(Collision_Invoker) @Read()


find_hits_in_bounds :: (spatial: *Collision_Spatial, bounds: AABB, self: Entity) -> [..] Hit_Result {
    result: [..] Hit_Result;
    result.allocator = temp;

    for other : spatial.bounds {
        if intersects(bounds, other) && spatial.entities[it_index] != self {
            hit: *Hit_Result = array_add(*result);
            hit.other = spatial.entities[it_index];
            hit.other_bounds = other;
        }
    }

    return result;
}