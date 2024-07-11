Charging :: struct @Component {}

Charging_Bundle :: struct @Bundle {
    anim_list_index: Anim_List_Index; //animation that will run during the charge 
    duration: Duration; //duration component, will make the charge kill itself after a duration
    charging: Charging; //tag must be put at end so the event fires when there is data
}

new_charge :: (world: *World, entity: Entity, charge_info: Charge) {
    child := spawn_child_entity(world, entity);
    add_components_from_bundle(world, child, Charging_Bundle.{
        anim_list_index.value = charge_info.anim_list_index,
        duration.value = charge_info.duration
    });   
}

start_charging :: (world: *World, entity: Entity) {
    #if SERVER {
        parent := get_parent(world, entity);
        if is_valid(world,parent){
            modify_interuptor_anim_slot(world, parent, entity);
        }
    }
} @Event(EcsOnAdd,Charging)





//tmp
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
                    
                    new_charge(q.world,q.entities[it],sword);
                }
            }
        }
    }
} @System(OnUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 

//tmp
test_attack2 :: (q: Query) {
    #if SERVER {
        player_commands := query_get(q, Player_Commands);
        positions := query_get(q, Position);
        cooldowns := query_get(q, Cooldown);

        for 0..q.count-1 {
            attacking := player_commands[it].secondary_attack;
            if attacking {
                if cooldowns[it].current_value <= 0 {
                    cooldowns[it].current_value = cooldowns[it].base_value;
                    
                    new_charge(q.world,q.entities[it],bow);
                }
            }
        }
    }
} @System(OnUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 

#load "charges.jai";









