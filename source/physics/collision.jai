Collider_AABB :: struct {
    #as using aabb: AABB;
}

Hit_Result :: struct {
    other: Entity;
    other_position: Vector2;
    other_aabb: AABB;
}

Collision_Invoker :: struct {
    hits_this_frame: [..] Hit_Result;
}

detect_collisions_system :: (world: *World) {
    // @Speed this can be optimized with AABB trees
    entities: [..] Entity;
    entities.allocator = temp;
    positions: [..] Position;
    positions.allocator = temp;
    colliders: [..] Collider_AABB;
    colliders.allocator = temp;

    for query : Query(Position, Collider_AABB).{world = world} {
        array_append(*entities, query.entities);
        array_append(*positions, query.position);
        array_append(*colliders, query.collider_aabb);
    }

    invoker_entities: [..] Entity;
    invoker_entities.allocator = temp;
    invoker_positions: [..] Position;
    invoker_positions.allocator = temp;
    invoker_colliders: [..] Collider_AABB;
    invoker_colliders.allocator = temp;

    for query : Query(Position, *Collision_Invoker, Collider_AABB).{world = world} {
        array_append(*invoker_entities, query.entities);
        array_append(*invoker_positions, query.position);
        array_append(*invoker_colliders, query.collider_aabb);
    }

    for a: 0..invoker_entities.count-1 {
        a_translated_aabb := translate(invoker_colliders[a], invoker_positions[a]);
        for b : 0..entities.count-1 {
            if invoker_entities[a] == entities[b] then continue;

            b_translated_aabb := translate(colliders[b], positions[b]);

            if intersects(a_translated_aabb, b_translated_aabb) {
                invoker := get_component(world, invoker_entities[a], Collision_Invoker);
                assert(invoker != null);

                hit_result: Hit_Result;
                hit_result.other = entities[b];
                hit_result.other_position = positions[b];
                hit_result.other_aabb = colliders[b].aabb;
                array_add(*invoker.hits_this_frame, hit_result);
            }
        }
    }

} @System

resolve_collisions :: (world: *World) {
    for query : Query(Collision_Invoker, *Position, Collider_AABB).{world = world} {
        invokers := query.collision_invoker;
        positions := query.position;
        colliders := query.collider_aabb;

        for 0..query.count-1 {
            bounds := translate(colliders[it], positions[it]);

            if invokers[it].hits_this_frame.count > 0 {
                // only handle the first overlap... for now.
                overlap := *invokers[it].hits_this_frame[0];
                overlapper_bounds := translate(overlap.other_aabb, overlap.other_position);
                minkowsky := minkowsky_difference(bounds, overlapper_bounds);
                penetration_vector := closest_point_on_aabb(minkowsky, .{0, 0});

                positions[it].value -= penetration_vector;
            }
        }
    }
}

/** Reset any hit results that might've been generated last frame. */
cleanup_collision_results_system :: (world: *World) {
    for query : Query(*Collision_Invoker).{world = world} {
        for 0..query.count-1 {
            query.collision_invoker[it].hits_this_frame.count = 0;
        }
    }
} @System

