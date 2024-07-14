
Skill :: struct @Component {
}

//@TODO this should be generated code or something
Fragment_List_Indecies :: enum {
    PROJECTILE;
}

Skill_Bundle :: struct @Bundle {
    power: Power; 
    power_change_queue: Power_Change_Queue; 
    skill: Skill;
    duration: Duration;
}

#if SERVER {
FRAGMENT_LIST :: (world: *World, skill: Entity).[add_projectile,];

new_skill :: (world: *World, entity: Entity, fragments: [..] Fragment_List_Indecies) {
    child := spawn_child_entity(world, entity);
    
    add_components_from_bundle(world, child, Skill_Bundle.{
        duration.base_value = 6.,
    });   

    for fragments {
        FRAGMENT_LIST[it](world, child);
    }

    //run at the end once the skill is initialized
    add_component(world, child, Networking_ID, .{get_unique_node_id()});
}
}

debug_childen_log_power :: (q: Query) {
    powers := query_get(q, Power);

    for 0..q.count-1 {
        log("hello i am % and my power is %", q.entities[it], powers[it].total);
    }
} @System(OnUpdate) @Write() @Read(Skill,Power)

#load "current_target.jai";
#load "skill_fragment.jai";
