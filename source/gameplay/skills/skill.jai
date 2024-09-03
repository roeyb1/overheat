Skill :: struct @Component {
    parent: Entity;
    fragments: [..] Fragment_List_Indecies;
}

Skill_Bundle :: struct @Bundle {
    networking_id: Networking_ID;
    power: Power; 
    power_change_queue: Power_Change_Queue; 
    powering_up: Powering_Up;
    skill: Skill;
    duration: Duration;
}

#if SERVER {
new_skill :: (world: *World, entity: Entity, fragments: [..] Fragment_List_Indecies) {
    child := spawn_child_entity(world, entity);
    
    add_components_from_bundle(world, child, Skill_Bundle.{
        networking_id = .{get_unique_node_id()},
        skill.parent = entity,
        skill.fragments = fragments,
        duration.value = 10.,
    });   

    for fragments {
        //temporary measure, maybe have fragment types that carry this behavior
        FRAGMENT_LIST[it](world, child);

        if it == .TOUCH then break;
    }
}

activate_skills :: (world: *World, parent: Entity) {
    children: [..] Entity;
    children.allocator = temp;
    for * iter : make_children_iter(world, parent, Powering_Up) {
        for iter.entities {
            if get_component(world, it, Skill) {
                    array_add(*children, it);
                
            }  
        }
    }  

    for children {
        remove_component(world, it, Powering_Up);
        add_component(world, it, Active);
    } 
}

get_skill_from_overlap_pair :: (world: *World, a: Entity, b: Entity) -> skill: Entity, target: Entity, found: bool {
    if get_component(world, a, Skill) {
        return a,b,true;
    } 
    if get_component(world, b, Skill) {
        return b,a,true;
    } 

    return a,b,false;
}
}

#load "size.jai";
#load "active.jai";
#load "powering_up.jai";
#load "skill_fragment.jai";
