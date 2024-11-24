Fragment_Storage :: struct @Component {
    self: [..] Fragment;
    payload: [..] Fragment;
    initialised := false;
}

//TODO: auto generate this
Fragment :: enum u8 {
    Touch;
    Projectile;
}

InheritFragmentsFrom :: struct @Pair { }

is_component_blocking :: (frag: Fragment) -> bool {
    if frag == {
        case .Touch;        return true;
        case .Projectile;   return true;
        case;               return false;
    }
}

#if SERVER {
    //when a new spell instance is created it will take the fragments his creator was meant to pass and seperate them based on what it's using and passing itself
    transfer_fragments :: (world: *World, entity: Entity) {
        //ensure there is info to be passed
        inherited_from := ecs_get_target(world, entity, InheritFragmentsFrom);
        if entity_is_valid(world, inherited_from) {
            blocked := false;
            payload := ecs_get(world, inherited_from, Fragment_Storage).payload;
            fragments := ecs_get(world, entity, Fragment_Storage);

            if payload {
                for payload {
                    
                    if !blocked{
                        array_add(*fragments.self, it);

                        //if the componenet that was added is "blocking" ie. demands a new behavior, then the rest fo the componenets will be stashed such
                        //that the next spell apply them using it's own modifiers
                        blocked = is_component_blocking(it);
                    } else {
                        array_add(*fragments.payload, it);
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
            if ecs_has(q.world, q.entities[index], Spell) {
                fragment_storage[index].initialised = true;
            }

            if !fragment_storage[index].initialised {
                self := fragment_storage[index].self;
                for self {
                    if it == {
                        case .Touch;
                            add_touch_from_cast(q.world, q.entities[index]);

                        case .Projectile;
                            add_projectile_fragment(q.world, q.entities[index]);
                    }
                }
                fragment_storage[index].initialised = true;
            }
        }
    } @System(OnValidate) @Write() @Read(Fragment_Storage)
}

#load "projectile.jai";
#load "touch.jai";