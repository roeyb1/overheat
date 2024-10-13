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

touch_overlap :: (world: *World, entity: Entity) {
        log("hi there");
        overlap := ecs_get(world, entity, Overlap_Pair);
        if overlap{
            skill,target,found := get_skill_from_overlap_pair(world, overlap.a, overlap.b);
            if found {
                effect := entity_spawn(world, parent = entity);
                ecs_add_pair(*g_world, effect, AttachedTo, target); 

                log("i hit %",target);
            }
        }
} @Event(EcsOnAdd,Overlap_Pair)

get_skill_from_overlap_pair :: (world: *World, a: Entity, b: Entity) -> skill: Entity, target: Entity, found: bool {
    if ecs_get(world, a, Spell) {
        return a,b,true;
    } 
    if ecs_get(world, b, Spell) {
        return b,a,true;
    } 

    return a,b,false;
}
