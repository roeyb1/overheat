
Test_Timebased_State :: struct @Component {}

Wind_Up :: struct @Component {
    // this member + tag is unfortunately needed or the component won't be tracked by the snapshot system and addition of the component will not be replicated
    placeholder: bool; @Sync 
}

Slam :: struct @Component {
    placeholder: bool; @Sync
}



test_attack :: (q: Query) {
    #if SERVER {
        player_commands := query_get(q, Player_Commands);
        positions := query_get(q, Position);
        cooldowns := query_get(q, Cooldown);

        for 0..q.count-1 {
            attacking := player_commands[it].main_attack;
            if attacking {
                if cooldowns[it].current_value <= 0 {
                    cooldowns[it].current_value = cooldowns[it].base_value;
                    log("yummy lemonade");
                    spawn_child_entity(q.world, q.entities[it],Test_Timebased_State,Duration);
                    //spawn_enemy(q.world, positions[it].value, get_unique_node_id(), .BAT);
                }
            }
        }
    }
} @System(PreUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 


test_timebased_state :: (world: *World, entity: Entity) {
    #if SERVER {
        parent := get_parent(world, entity);
        slam := #run component_type_id(Slam);

        if is_valid(world,parent){
            assert(get_component(world, parent, Player) != null);
            if has_component(world,parent,slam) {
                remove_component(world,parent,Slam);
            }
            add_component(world,parent,Wind_Up);
        }
    }
} @Event(EcsOnAdd,Test_Timebased_State)

test_timebased_state_removal :: (world: *World, entity: Entity) {
    #if SERVER {
        parent := get_parent(world, entity);
        if (get_component(world,parent,Wind_Up)){
            remove_component(world,parent,Wind_Up);
            add_component(world,parent,Slam);
        }
    }
} @Event(EcsOnRemove,Test_Timebased_State)

