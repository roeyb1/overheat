Fragments :: struct @Component {
    components: [..] Type;
    current_index := 0; 
}

BLOCKING_COMPONENTS: [1]Type = .[Touch];

process_fragments :: (world: *World, entity: Entity) {
    using fragments := ecs_get(world, entity, Fragments);
    
    if fragments {
        for current_index..components.count-1 {
            ecs_add(world, entity, components[it]);

            //if the componenet that was added is "blocking" ie. demands a new behavior, then the rest fo the componenets will be stashed such
            //that the blocking componenet can apply them using it's own modifiers
            if array_find(BLOCKING_COMPONENTS,components[it]) {
                current_index = it;
                break;
            }
        }
    }
}

#load "projectile.jai";
#load "touch.jai";