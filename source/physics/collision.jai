Collider_AABB :: struct {
    #as using aabb: AABB;
    blocking: bool;
}

Hit_Result :: struct {
    other: Entity;
    other_position: Vector2;
    other_aabb: AABB;
}

Collision_Invoker :: struct {
    /** List of all hit results which were generated against this entity this frame */
    hits_this_frame: [..] Hit_Result;
    /** List of all hit results against colliders that are "blocking" which were generated against this entity this frame */
    blocking_hits_this_frame: [..] Hit_Result;
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
                if colliders[b].blocking {
                    array_add(*invoker.blocking_hits_this_frame, hit_result);
                }
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
            for *hit : invokers[it].blocking_hits_this_frame {
                invoker_bounds := translate(colliders[it], positions[it]);

                overlapper_bounds := translate(hit.other_aabb, hit.other_position);
                minkowsky := minkowsky_difference(invoker_bounds, overlapper_bounds);
                // check if there even is still a collision. We may no longer be colliding due to the collision resolution of any previous hits.
                // We can do this by checking if the minkowsky diff still contains the origin:
                if is_inside(minkowsky, .{0, 0}) {
                    penetration_vector := closest_point_on_aabb(minkowsky, .{0, 0});

                    positions[it].value -= penetration_vector;
                }
            }
        }
    }
}

/** Reset any hit results that might've been generated last frame. */
reset_collision_results :: (world: *World) {
    for query : Query(*Collision_Invoker).{world = world} {
        for 0..query.count-1 {
            query.collision_invoker[it].hits_this_frame.count = 0;
        }
    }
} @System

