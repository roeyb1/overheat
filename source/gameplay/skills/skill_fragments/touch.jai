//touch is a vector by which fragments can be applied when a collision is generated
Touch :: struct @Component {
    fragments: [..] Fragment_List_Indecies;
}

Resolve_Touch :: struct @Component {
    target: Entity;
}

#if SERVER {
add_touch :: (world: *World, skill: Entity){ 
    touch_found := false;
    touch := add_component(world, skill, Touch);
    fragments := get_component(world, skill, Skill).fragments;

    for fragments {
        if touch_found {
            array_add(*touch.fragments,it);
        } 

        if it == .TOUCH then touch_found = true;
    }
}

Resolve_Touch_Bundle :: struct @Bundle {
    power: Power;
    resolve_touch: Resolve_Touch;
}

touch_collide :: (world: *World, entity: Entity) {
        overlap := get_component(world, entity, Overlap_Pair);
        if get_component(world, entity, Overlap_Pair){
            skill,target,found := get_skill_from_overlap_pair(world, overlap.a, overlap.b);
            if found {
                touch := get_component(world, skill, Touch);
                total_power := get_component(world, skill, Power);
                if (touch) {
                    resolve_touch := spawn_entity_from_bundle(*g_world, Resolve_Touch_Bundle.{
                        power = total_power,
                        resolve_touch.target = target
                    });

                    for touch.fragments {
                        FRAGMENT_LIST[it](world, resolve_touch);
                    }
                }
            }
        }
} @Event(EcsOnAdd,Overlap_Pair)
}