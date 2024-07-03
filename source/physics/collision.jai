Collider_AABB :: struct @Component {
    #as using aabb: AABB;

    blocking: bool;
}

Collision_Invoker :: struct @Component {
    // globally unique id that is shared across network (server and clients should all match for a given entity)
    id: u64;
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
    /** list of all overlaps, including blocking */
    pairs: [..] Overlap_Pair;

    /** filtered list of only blocking overlaps */
    blocking_pairs: [..] Overlap_Pair;
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

            array_add(*collision_list.pairs, overlap);
            if overlap.blocking {
                array_add(*collision_list.blocking_pairs, overlap);
            }
        }
    }
} @System(OnValidate) @Write(Collision_List) @Read(Collision_Invoker,Position,Collider_AABB,Collision_Spatial)

sort_hit_pairs :: (q: Query) {
    hit_list := get_singleton(q.world, Collision_List);

    quick_sort(hit_list.pairs, (hit) => hit.sort_key);
} @System(OnUpdate) @Write(Collision_List) @Read()

emit_overlap_events :: (q: Query) {
    collision_list := get_singleton(q.world, Collision_List);
    for pair : collision_list.pairs {
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

    array_reset(*collision_list.pairs);
    array_reset(*collision_list.blocking_pairs);
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

find_nearest_matching_predicate :: (world: *World, point: Vector2, self: Entity, pred: #type (entity: Entity, data: *void) -> (bool), data: *void) -> Entity, bool {
    // @Speed accelerate with AABB tree
    candidates: [..] Entity;
    candidates.allocator = temp;
    distances: [..] float;
    distances.allocator = temp;

    for q : make_iter(world, Position) {
        positions := query_get(q, Position);
        for 0..q.count-1 {
            if q.entities[it] != self {
                if pred(q.entities[it], data) {
                    array_add(*candidates, q.entities[it]);
                    array_add(*distances, length(point - positions[it]));
                }
            }
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

#load "aabb_tree.jai";