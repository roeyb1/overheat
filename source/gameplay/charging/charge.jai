Charging :: struct @Component {}

Charging_Bundle :: struct @Bundle {
    anim_list_index: Anim_List_Index; //animation that will run during the charge 
    duration: Duration; //duration component, will make the charge kill itself after a duration
    energy_cost: Energy_Cost; // needs to be put after the duration componenent @TODO we need a way of executing events in a specific order other then in the bundle this is error prone and cringe to debug
    charging: Charging; //tag must be put at end so the event fires when there is data
}

new_charge :: (world: *World, parent: Entity, charge_info: Charge) {
    child := entity_spawn(world, parent = parent);
    ecs_add_bundle(world, child, Charging_Bundle.{
        anim_list_index.value = charge_info.anim_list_index,
        duration.value = charge_info.duration,
        energy_cost.total = charge_info.energy_cost
    });   
}

start_charging :: (world: *World, entity: Entity) {
        parent := ecs_get_target(world, entity, Child_Of);
        if entity_is_valid(world, parent){
            modify_interuptor_anim_slot_from_charge(world, parent, entity);
        }
} @Event(EcsOnAdd,Charging)

//while a charge exists, it will send power to it's parent player in exchange for his mana
update_charging :: (q: Query) {
    energy_costs := query_get(q, Energy_Cost);

    for 0..q.count-1 {
        parent := ecs_get_target(q.world, q.entities[it], Child_Of);
        if entity_is_valid(q.world, parent){
            health_queue := ecs_get(q.world, parent, Health_Change_Queue);
            if health_queue {
                drain_energy_per_tick(health_queue,energy_costs[it]);
                
                //for now this lives here but eventually each charge could update it's power in a system
                gather_power(q.world,parent,5.);
            }
        }
    }
} @System(OnUpdate) @Write() @Read(Charging,Energy_Cost) 


//temporary way of translating user input into an ability cast on the server, should be fleshed out when proper support is available
#if SERVER {
test_attack :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    positions := query_get(q, Position);
    cooldowns := query_get(q, Cooldown);

    for 0..q.count-1 {
        attacking := player_commands[it].main_attack;
        if attacking {
            if cooldowns[it].current_value <= 0 {
                cooldowns[it].current_value = cooldowns[it].base_value;
                
                new_charge(q.world,q.entities[it],sword);

                //tmp
                fragments: [..] Fragment_List_Indecies;
                array_add(*fragments, Fragment_List_Indecies.PROJECTILE);
                new_skill(q.world,q.entities[it], fragments);
            }
        }
    }
} @System(OnUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 


//see above 
test_attack2 :: (q: Query) {
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
} @System(OnUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 
}

#load "charges.jai";
#load "energy_cost.jai";








