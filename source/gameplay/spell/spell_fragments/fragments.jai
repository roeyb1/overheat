Fragment_Storage :: struct @Component {
    fragments_to_apply: [..] Fragments;
    fragments_to_pass: [..] Fragments;
    initialised := false;
}

//TODO: auto generate this
Fragments :: enum u8 {
        Touch;
        Projectile_Fragment;
        Projectile;
}

InheritFragmentsFrom :: struct @Pair { }

FRAGMENTS_COMPONENTS: [3]Type = .[Touch,Projectile_Fragment,Projectile];
BLOCKING_COMPONENTS: [3]Fragments = .[.Touch,.Projectile_Fragment,.Projectile];

#if SERVER {
//when a new spell instance is created it will take the fragments his creator was meant to pass and seperate them based on what it's using and passing itself
transfer_fragments :: (world: *World, entity: Entity) {
        //ensure there is info to be passed
        inherited_from := ecs_get_target(world, entity, InheritFragmentsFrom);
        if entity_is_valid(world, inherited_from) {
            blocked := false;
            fragments_to_pass := ecs_get(world, inherited_from, Fragment_Storage).fragments_to_pass;
            fragments := ecs_get(world, entity, Fragment_Storage);

            if fragments_to_pass {
                for fragments_to_pass {
                    
                    if !blocked{
                        array_add(*fragments.fragments_to_apply, it);

                        //if the componenet that was added is "blocking" ie. demands a new behavior, then the rest fo the componenets will be stashed such
                        //that the next spell apply them using it's own modifiers
                        if array_find(BLOCKING_COMPONENTS, it) {
                            blocked = true;    
                        }
                    }
                    else {
                        array_add(*fragments.fragments_to_pass, it);
                    }
                }
            }
        }
} @Event(EcsOnAdd,Fragment_Storage)

//once the fragents are ready the spell isntance will apply the components from the fragments
//TODO would need a not here
initialize_Fragments :: (q: Query) {
    fragment_storage := query_get(q, Fragment_Storage);

    for index: 0..q.count-1 {
        //a not would allow to remove this check
        if ecs_get(q.world, q.entities[index], Spell) {
            fragment_storage[index].initialised = true;
        }
        if !fragment_storage[index].initialised {
            fragments_to_apply := fragment_storage[index].fragments_to_apply;
            for fragments_to_apply {
                if it == {
                case .Touch;
                    add_touch_from_cast(q.world, q.entities[index]);

                case .Projectile_Fragment;
                    add_projectile_fragment(q.world, q.entities[index]);

                case .Projectile;
                    add_projectile(q.world, q.entities[index]);
            
                }
            }
            fragment_storage[index].initialised = true;
        }
    }
} @System(OnValidate) @Write() @Read(Fragment_Storage)
}



#load "projectile.jai";
#load "touch.jai";