Touch :: struct @Component {
    
}

add_touch :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, CastBy);
    if entity_is_valid(world,parent){

        BASE_COLLIDER_SIZE :: Vector2.{1., 1.};
        bounds := make_aabb(.{0,0}, BASE_COLLIDER_SIZE);
        ecs_add(world, entity, Collider_AABB.{bounds, false});
        ecs_add(world, entity, Collision_Invoker.{ id = cast(u64) entity.raw , generate_overlap_events = true });
    }
} @Event(EcsOnAdd,Touch)

projectile_collide :: (world: *World, entity: Entity) {
        overlap := ecs_get(world, entity, Overlap_Pair);

        aabb_a := ecs_get(world, overlap.a, Collider_AABB);
        position_a := ecs_get(world, overlap.a, Position);
        aabb_b := ecs_get(world, overlap.b, Collider_AABB);
        position_b := ecs_get(world, overlap.b, Position);

        aabb_a_min := ecs_get(world, overlap.a, Collider_AABB).aabb.min;
        aabb_a_max := ecs_get(world, overlap.a, Collider_AABB).aabb.max;

        translation_a := translate(aabb_a, position_a);
        translation_b := translate(aabb_b, position_b);
        
        log("entity a translated value is: %",translation_a);
        //log("entity a max is: %",position_a_max);
        log("aabb a bounding box is : % , %",aabb_a_min,aabb_a_max);
        log("entity b translated value is: %",translation_b);
        //log("entity b max is: %",position_b_max);
} @Event(EcsOnAdd,Overlap_Pair)
