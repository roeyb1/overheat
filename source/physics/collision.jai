Collider_AABB :: struct @Component {
    #as using aabb: AABB;

    blocking: bool;
}

Hit_Result :: struct {
    other: Entity;
    other_bounds: AABB;
}

Hit_Pair :: struct {
    sort_key: u64;

    a: Entity;
    b: Entity;

    a_bounds: AABB;
    b_bounds: AABB;
}

Collision_Invoker :: struct @Component {
    // globally unique id that is shared across network (server and clients should all match for a given entity)
    id: u64;
}

Collision_Spatial :: struct @SingletonComponent {
    // @Speed this will be optimized with an AABB tree
    bounds: [..] Collider_AABB;
    entities: [..] Entity;
    sort_keys: [..] u64; // 0 everywhere except when an entity has a unique networking key
}

Hit_Result_List :: struct @SingletonComponent {
    pairs: [..] Hit_Pair;
}

reset_collision_spatial :: (q: Query) {
    spatial := get_singleton(q.world, Collision_Spatial);

    // rebuild the spatial from scratch every frame.
    // #todo: only update the pieces that changed using events
    spatial.entities.count = 0;
    spatial.bounds.count = 0;
    spatial.sort_keys.count = 0;
} @System(PreUpdate) @Write(Collision_Spatial) @Read()

build_collision_spatial :: (q: Query) {
    spatial := get_singleton(q.world, Collision_Spatial);

    colliders := query_get(q, Collider_AABB);
    positions := query_get(q, Position);
    invokers := query_get_opt(q, Collision_Invoker);

    array_append(*spatial.entities, q.entities);

    array_reserve(*spatial.bounds, spatial.bounds.count + q.count);
    array_reserve(*spatial.sort_keys, spatial.sort_keys.count + q.count);
    for 0..q.count-1 {
        array_add(*spatial.bounds, .{translate(colliders[it], positions[it]), colliders[it].blocking});

        if invokers {
            array_add(*spatial.sort_keys, invokers[it].id);
        } else {
            array_add(*spatial.sort_keys, 0);
        }
    }
} @System(OnValidate) @Write(Collision_Spatial) @Read(Position,Collider_AABB) @Optional(Collision_Invoker)

detect_collisions :: (q: Query) {
    invokers := query_get(q, Collision_Invoker);
    positions := query_get(q, Position);
    colliders := query_get(q, Collider_AABB);

    spatial := get_singleton(q.world, Collision_Spatial);
    hit_list := get_singleton(q.world, Hit_Result_List);

    for 0..q.count-1 {
        translated_aabb := translate(colliders[it], positions[it]);
        hits := generate_hit_pairs_for_entity(spatial, translated_aabb, q.entities[it], invokers[it].id);

        array_append(*hit_list.pairs, hits);
    }
} @System(OnValidate) @Write(Hit_Result_List) @Read(Collision_Invoker,Position,Collider_AABB,Collision_Spatial)

sort_hit_pairs :: (q: Query) {
    // sort hits by entity id

    hit_list := get_singleton(q.world, Hit_Result_List);

    quick_sort(hit_list.pairs, (hit) => hit.sort_key);
} @System(PostUpdate) @Write(Hit_Result_List) @Read()

resolve_collisions :: (q: Query) {
    hit_list := get_singleton(q.world, Hit_Result_List);

    for *pair : hit_list.pairs {
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
    
    hit_list.pairs.count = 0;
} @System(PostUpdate) @Write(Position) @Read(Hit_Result_List)

generate_hit_pairs_for_entity :: (spatial: *Collision_Spatial, bounds: AABB, self: Entity, sort_key: u64) -> [..] Hit_Pair {
    result: [..] Hit_Pair;
    result.allocator = temp;

    for other : spatial.bounds {
        if intersects(bounds, other) && spatial.entities[it_index] != self {
            // track hit pairs for collision resolution, but only if they are blocking hits, otherwise we just emit an overlap event:
            // @todo: actually emit events for overlaps
            if other.blocking {
                pair: *Hit_Pair = array_add(*result);
                if spatial.sort_keys[it_index] == 0 || sort_key < spatial.sort_keys[it_index] {
                    pair.sort_key = sort_key;
                    pair.a = self;
                    pair.a_bounds = bounds;

                    pair.b = spatial.entities[it_index];
                    pair.b_bounds = other;
                } else {
                    pair.sort_key = spatial.sort_keys[it_index];
                    pair.b = self;
                    pair.b_bounds = bounds;

                    pair.a = spatial.entities[it_index];
                    pair.a_bounds = other;
                }
            }
        }
    }

    return result;
}