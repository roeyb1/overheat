Collider_AABB :: struct {
    #as using aabb: AABB;
}

Collision_Result :: struct {
    other: Entity;
    other_position: Position;
    other_collider: Collider_AABB;
}

detect_collisions_system :: (world: *World) {
    // @Speed this can be optimized with AABB trees
    for a_query, a_index : Query(Position, Collider_AABB).{world = world} {
        a_translated_aabb := translate(a_query.collider_aabb, a_query.position);

        for b_query, b_index : Query(Position, Collider_AABB).{world = world} {
            if a_index == b_index then continue;

            b_translated_aabb := translate(b_query.collider_aabb, b_query.position);

            if intersects(a_translated_aabb, b_translated_aabb) {
                add_component(world, a_index, Collision_Result, .{ b_index, b_query.position, b_query.collider_aabb });
            }
        }
    }
} @System

/** Remove any collision results that we created this frame. We've already processed them by this point */
cleanup_collision_results_system :: (world: *World) {
    // @Todo: requiring the user to indicate that the query shouldn't use the cache kind of sucks... Best solution I have for now though.
    for :Uncached Query(Collision_Result).{world = world} {
        remove_component(world, it_index, Collision_Result);
    }
} @System

