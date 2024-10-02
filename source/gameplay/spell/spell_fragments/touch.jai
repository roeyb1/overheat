Touch :: struct @Component {
    
}

add_touch :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, CastBy);
    if entity_is_valid(world,parent){
        position := ecs_get(world, entity, Position).value;
        BASE_COLLIDER_SIZE :: Vector2.{1., 1.};
        bounds := make_aabb(position, BASE_COLLIDER_SIZE);
        ecs_add(world, entity, Collider_AABB.{bounds, true});
        ecs_add(world, entity, Collision_Invoker.{ id = cast(u64) entity.raw });
    }
} @Event(EcsOnAdd,Touch)