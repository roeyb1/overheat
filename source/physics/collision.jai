Collider_AABB :: struct @Component {
    #as using aabb: AABB; @Sync

    blocking: bool; @Sync
}

Collision_Invoker :: struct @Component {
    // globally unique id that is shared across network (server and clients should all match for a given entity)
    id: u64; @Sync
    generate_overlap_events := false; @Sync
}

Overlap_Pair :: struct @Component {
    a: Entity;
    b: Entity;

    sort_key: u64;
    blocking: bool;
}

Collision_Spatial :: struct @SingletonComponent {
    aabb_tree: BoundingTree(Entity);
}

Collision_List :: struct @SingletonComponent {
    /** Filtered + sorted list of only blocking overlaps */
    blocking_pairs: [..] Overlap_Pair;

    /** Filtered + sorted list of only the overlaps that should generate events. */
    event_pairs: [..] Overlap_Pair;
}

reset_collision_spatial :: (q: Query) {
    spatial := ecs_singleton_get(q.world, Collision_Spatial);

    // rebuild the spatial from scratch every frame.
    tree_reset(*spatial.aabb_tree);
    // #todo: only update the pieces that changed using events
} @Predict @System(OnUpdate) @Write(Collision_Spatial) @Read()

build_collision_spatial :: (q: Query) {
    spatial := ecs_singleton_get(q.world, Collision_Spatial);

    colliders := query_get(q, Collider_AABB);
    positions := query_get(q, Position);

    for 0..q.count-1 {
        bounds := translate(colliders[it], positions[it]);

        create_proxy(*spatial.aabb_tree, bounds, q.entities[it]);
    }
} @Predict @System(OnValidate) @Write(Collision_Spatial) @Read(Position,Collider_AABB) @Optional(Collision_Invoker)

Overlap_Pair_Bundle :: struct @Bundle {
    overlap_pair: Overlap_Pair;
    transient: Transient;
}

detect_collisions :: (q: Query) {
    invokers := query_get(q, Collision_Invoker);
    positions := query_get(q, Position);
    colliders := query_get(q, Collider_AABB);

    spatial := ecs_singleton_get(q.world, Collision_Spatial);
    collision_list := ecs_singleton_get(q.world, Collision_List);

    for 0..q.count-1 {
        translated_aabb := translate(colliders[it], positions[it]);
        overlaps := generate_overlap_pairs_for_entity(spatial, translated_aabb, q.entities[it], invokers[it].id);

        for * overlap : overlaps {
            b_collider := ecs_get(q.world, overlap.b, Collider_AABB);

            overlap.blocking = b_collider.blocking;
            overlap.sort_key = invokers[it].id;

            if invokers[it].generate_overlap_events {
                array_add(*collision_list.event_pairs, overlap);
            }
            if overlap.blocking {
                array_add(*collision_list.blocking_pairs, overlap);
            }
        }
    }
} @Predict @System(OnValidate) @Write(Collision_List) @Read(Collision_Invoker,Position,Collider_AABB,Collision_Spatial)

sort_hit_pairs :: (q: Query) {
    hit_list := ecs_singleton_get(q.world, Collision_List);

    quick_sort(hit_list.blocking_pairs, (hit) => hit.sort_key);
    quick_sort(hit_list.event_pairs, (hit) => hit.sort_key);
} @Predict @System(OnUpdate) @Write(Collision_List) @Read()

emit_overlap_events :: (q: Query) {
    collision_list := ecs_singleton_get(q.world, Collision_List);
    for pair : collision_list.event_pairs {
        overlap_entity := entity_spawn_bundle(q.world, Overlap_Pair_Bundle.{overlap_pair = pair});
    }
} @System(OnValidate) @Write() @Read(Collision_List) @OptionalWrite(Overlap_Pair)

resolve_overlap :: (q: Query) {
    collision_list := ecs_singleton_get(q.world, Collision_List);
    for pair : collision_list.blocking_pairs {
        if !entity_is_valid(q.world, pair.a) || !entity_is_valid(q.world, pair.b) then continue;

        a_pos := ecs_get(q.world, pair.a, Position);
        a_collider := ecs_get(q.world, pair.a, Collider_AABB);
        a_bounds := translate(a_collider, a_pos);

        b_pos := ecs_get(q.world, pair.b, Position);
        b_collider := ecs_get(q.world, pair.b, Collider_AABB);
        b_bounds := translate(b_collider, b_pos);

        minkowsky := minkowsky_difference(a_bounds, b_bounds);
        if is_inside(minkowsky, .{0, 0}) {
            penetration_vector := closest_point_on_aabb(minkowsky, .{0, 0});

            // if the second entity has a collision invoker, we will handle half of the resolution here
            if ecs_get(q.world, pair.b, Collision_Invoker) {
                a_pos.value -= penetration_vector / 2.;
                b_pos.value += penetration_vector / 2.;
            } else {
                a_pos.value -= penetration_vector;
            }
        }
    }

    array_reset(*collision_list.blocking_pairs);
    array_reset(*collision_list.event_pairs);
} @Predict @System(PostUpdate) @Write() @Read(Collision_List) @OptionalWrite(Position,Collision_Write_Fence)

generate_overlap_pairs_for_entity :: (spatial: *Collision_Spatial, bounds: AABB, self: Entity, sort_key: u64) -> [..] Overlap_Pair {
    result: [..] Overlap_Pair;
    result.allocator = temp;

    for query(*spatial.aabb_tree, bounds) {
        if it == self then continue;

        pair: *Overlap_Pair = array_add(*result);
        pair.a = self;

        pair.b = it;
    }

    return result;
}

find_nearest_matching_predicate_within_range :: (world: *World, point: Vector2, radius: float, self: Entity, pred: #type (entity: Entity, data: *void) -> (bool), data: *void) -> Entity, bool {
    spatial := ecs_singleton_get(world, Collision_Spatial);
    min_entity := INVALID_ENTITY;
    min_distance := FLOAT32_MAX;
    for query(*spatial.aabb_tree, make_aabb(point, make_vector2(radius))) {
        if it == self then continue;

        if pred(it, data) {
            bounds := spatial.aabb_tree.nodes[it_index].aabb;
            position := box_center(bounds);
            dist := distance(point, position);
            if dist < min_distance {
                min_entity = it;
                min_distance = dist;
            }
        }
    }

    if min_entity == INVALID_ENTITY {
        return INVALID_ENTITY, false;
    }

    return min_entity, true;
}
