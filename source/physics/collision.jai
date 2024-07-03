Collider_AABB :: struct @Component {
    #as using aabb: AABB;

    blocking: bool;
}

Collision_Invoker :: struct @Component {
    // globally unique id that is shared across network (server and clients should all match for a given entity)
    id: u64;
    generate_overlap_events := false;
}

Overlap_Pair :: struct @Component {
    a: Entity;
    b: Entity;

    sort_key: u64;
    blocking: bool;
}

Collision_Spatial :: struct @SingletonComponent {
    aabb_tree: AABB_Tree;
}

Collision_List :: struct @SingletonComponent {
    /** Filtered + sorted list of only blocking overlaps */
    blocking_pairs: [..] Overlap_Pair;

    /** Filtered + sorted list of only the overlaps that should generate events. */
    event_pairs: [..] Overlap_Pair;
}

reset_collision_spatial :: (q: Query) {
    spatial := get_singleton(q.world, Collision_Spatial);

    // rebuild the spatial from scratch every frame.
    tree_reset(*spatial.aabb_tree);
    // #todo: only update the pieces that changed using events
} @System(OnUpdate) @Write(Collision_Spatial) @Read()

build_collision_spatial :: (q: Query) {
    spatial := get_singleton(q.world, Collision_Spatial);

    colliders := query_get(q, Collider_AABB);
    positions := query_get(q, Position);

    for 0..q.count-1 {
        bounds := translate(colliders[it], positions[it]);

        insert(*spatial.aabb_tree, bounds, q.entities[it]);
    }
} @System(OnValidate) @Write(Collision_Spatial) @Read(Position,Collider_AABB) @Optional(Collision_Invoker)

Overlap_Pair_Bundle :: struct @Bundle {
    overlap_pair: Overlap_Pair;
    transient: Transient;
}

detect_collisions :: (q: Query) {
    invokers := query_get(q, Collision_Invoker);
    positions := query_get(q, Position);
    colliders := query_get(q, Collider_AABB);

    spatial := get_singleton(q.world, Collision_Spatial);
    collision_list := get_singleton(q.world, Collision_List);

    for 0..q.count-1 {
        translated_aabb := translate(colliders[it], positions[it]);
        overlaps := generate_overlap_pairs_for_entity(spatial, translated_aabb, q.entities[it], invokers[it].id);

        for * overlap : overlaps {
            b_collider := get_component(q.world, overlap.b, Collider_AABB);

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
} @System(OnValidate) @Write(Collision_List) @Read(Collision_Invoker,Position,Collider_AABB,Collision_Spatial)

sort_hit_pairs :: (q: Query) {
    hit_list := get_singleton(q.world, Collision_List);

    quick_sort(hit_list.blocking_pairs, (hit) => hit.sort_key);
    quick_sort(hit_list.event_pairs, (hit) => hit.sort_key);
} @System(OnUpdate) @Write(Collision_List) @Read()

emit_overlap_events :: (q: Query) {
    collision_list := get_singleton(q.world, Collision_List);
    for pair : collision_list.event_pairs {
        overlap_entity := spawn_entity_from_bundle(q.world, Overlap_Pair_Bundle.{overlap_pair = pair});
    }
} @System(OnValidate) @Write() @Read(Collision_List) @OptionalWrite(Overlap_Pair)

resolve_overlap :: (q: Query) {
    collision_list := get_singleton(q.world, Collision_List);
    for pair : collision_list.blocking_pairs {

        a_pos := get_component(q.world, pair.a, Position);
        a_collider := get_component(q.world, pair.a, Collider_AABB);
        a_bounds := translate(a_collider, a_pos);

        b_pos := get_component(q.world, pair.b, Position);
        b_collider := get_component(q.world, pair.b, Collider_AABB);
        b_bounds := translate(b_collider, b_pos);

        minkowsky := minkowsky_difference(a_bounds, b_bounds);
        if is_inside(minkowsky, .{0, 0}) {
            penetration_vector := closest_point_on_aabb(minkowsky, .{0, 0});

            // if the second entity has a collision invoker, we will handle half of the resolution here
            if get_component(q.world, pair.b, Collision_Invoker) {
                a_pos.value -= penetration_vector / 2.;
                b_pos.value += penetration_vector / 2.;
            } else {
                a_pos.value -= penetration_vector;
            }
        }
    }

    array_reset(*collision_list.blocking_pairs);
    array_reset(*collision_list.event_pairs);
} @System(PostUpdate) @Write() @Read(Collision_List) @OptionalWrite(Position)

generate_overlap_pairs_for_entity :: (spatial: *Collision_Spatial, bounds: AABB, self: Entity, sort_key: u64) -> [..] Overlap_Pair {
    result: [..] Overlap_Pair;
    result.allocator = temp;

    overlaps := find_overlaps(*spatial.aabb_tree, bounds, self);

    for overlaps {
        pair: *Overlap_Pair = array_add(*result);
        pair.a = self;

        pair.b = it.entity;
    }

    return result;
}

find_nearest_matching_predicate_within_range :: (world: *World, point: Vector2, radius: float, self: Entity, pred: #type (entity: Entity, data: *void) -> (bool), data: *void) -> Entity, bool {
    spatial := get_singleton(world, Collision_Spatial);

    candidates := find_overlaps(*spatial.aabb_tree, make_aabb(point, make_vector2(2 * radius)), self);

    min_entity := INVALID_ENTITY;
    min_distance := FLOAT32_MAX;
    for candidates {
        if pred(it.entity, data) {
            position := box_center(it.bounds);
            dist := distance(point, position);
            if dist < min_distance {
                min_entity = it.entity;
                min_distance = dist;
            }
        }
    }

    if min_entity == INVALID_ENTITY {
        return INVALID_ENTITY, false;
    }

    return min_entity, true;
}

#load "aabb_tree.jai";