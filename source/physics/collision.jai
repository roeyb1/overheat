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
}

Collision_Spatial :: struct @SingletonComponent {
    aabb_tree: AABB_Tree;
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

detect_collisions :: (q: Query) {

    Overlap_Pair_Bundle :: struct @Bundle {
        overlap_pair: Overlap_Pair;
        transient: Transient;
    }

    invokers := query_get(q, Collision_Invoker);
    positions := query_get(q, Position);
    colliders := query_get(q, Collider_AABB);

    spatial := get_singleton(q.world, Collision_Spatial);

    for 0..q.count-1 {
        translated_aabb := translate(colliders[it], positions[it]);
        overlaps := generate_overlap_pairs_for_entity(spatial, translated_aabb, q.entities[it], invokers[it].id);

        for overlap : overlaps {
            overlap_entity := spawn_entity_from_bundle(q.world, Overlap_Pair_Bundle.{overlap_pair = overlap});
        }
    }
} @System(OnValidate) @Write() @Read(Collision_Invoker,Position,Collider_AABB,Collision_Spatial) @OptionalWrite(Overlap_Pair)

/*
sort_hit_pairs :: (q: Query) {
    // sort hits by entity id

    hit_list := get_singleton(q.world, Hit_Result_List);

    quick_sort(hit_list.pairs, (hit) => hit.sort_key);
} @System(PostUpdate) @Write(Hit_Result_List) @Read()
*/

resolve_overlap :: (world: *World, entity: Entity) {
    pair := get_component(world, entity, Overlap_Pair);
    a_pos := get_component(world, pair.a, Position);
    a_collider := get_component(world, pair.a, Collider_AABB);
    a_bounds := translate(a_collider, a_pos);

    b_pos := get_component(world, pair.b, Position);
    b_collider := get_component(world, pair.b, Collider_AABB);
    b_bounds := translate(b_collider, b_pos);

    minkowsky := minkowsky_difference(a_bounds, b_bounds);
    if is_inside(minkowsky, .{0, 0}) {
        penetration_vector := closest_point_on_aabb(minkowsky, .{0, 0});

        // if the second entity has a collision invoker, we will handle half of the resolution here
        if get_component(world, pair.b, Collision_Invoker) {
            a_pos.value -= penetration_vector / 2.;
        } else {
            a_pos.value -= penetration_vector;
        }
    }
} @Event(EcsOnAdd,Overlap_Pair) @Write(Position)

    /*
resolve_overlap :: (world: *World, entity: Entity) {
    overlap := get_component(world, entity, Collision_Overlap);

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
        } else {
            a_pos.value -= penetration_vector;
        }
    }
} @System(PostUpdate) @Write(Position) @Read(Hit_Result_List)
    */

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