Effect :: struct @Component {
}

AttachedTo :: struct @Pair { }

//an effect is an entity that gets initialized when components such as HASTE get added to a vector. it will create the effect which will then be 
//attached to the intended target, once it's attached it will run it's course and do whatever is in the HASTE system 

initialize_effect :: (world: *World, entity: Entity) {
    fragments := ecs_get(world, entity, Fragments);  
    
    process_fragments(world,entity);

} @Event(EcsOnAdd,Effect)