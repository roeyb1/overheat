Collider_AABB :: struct {
    #as using aabb: AABB;
}

Collision_Invoker :: struct {}

Collision_Result :: struct {
    other: Entity;
    other_position: Vector2;
    other_aabb: AABB;
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

    invokers: [..] Entity;
    invokers.allocator = temp;
    invoker_positions: [..] Position;
    invoker_positions.allocator = temp;
    invoker_colliders: [..] Collider_AABB;
    invoker_colliders.allocator = temp;

    for query : Query(Position, Collision_Invoker, Collider_AABB).{world = world} {
        array_append(*invokers, query.entities);
        array_append(*invoker_positions, query.position);
        array_append(*invoker_colliders, query.collider_aabb);
    }

    for a: 0..invokers.count-1 {
        a_translated_aabb := translate(invoker_colliders[a], invoker_positions[a]);
        for b : 0..entities.count-1 {
            if invokers[a] == entities[b] then continue;

            b_translated_aabb := translate(colliders[b], positions[b]);

            if intersects(a_translated_aabb, b_translated_aabb) {
            }
        }
    }

} @System

/** Remove any collision results that we created this frame. We've already processed them by this point */
cleanup_collision_results_system :: (world: *World) {
    for Query(*Collider_AABB).{world = world} {
    }
} @System

