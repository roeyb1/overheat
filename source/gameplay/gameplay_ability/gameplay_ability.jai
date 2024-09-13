Gameplay_Ability :: struct @Component {
        owner: Entity;
}

Gameplay_Ability_Bundle :: struct @Bundle {
    gameplay_ability: Gameplay_Ability;
    cooldown: Cooldown;
}

OwnedBy :: struct @Pair { }

//the GA_State_Ready tag gets added to a gameplay ability when it ready to fire.
//it will then be switched to triggered once it is clicked and the associated gameplay logic will be executed. 
GA_State_Dormant :: struct @Tag {}

GA_State_Ready :: struct @Tag {}

GA_State_Triggered :: struct @Tag {} 

//the binding tags let the server know what button should trigger a gameplay ability
Bound_To_1 :: struct @Tag {}
Bound_To_2 :: struct @Tag {}
Bound_To_3 :: struct @Tag {}

//checks player commands and executes the appropriate gameplay ability when a button is pressed based on the Bound_To Tags
trigger_gameplay_ability :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    
    for 0..q.count-1 {
        if player_commands[it].ability_1 {
            trigger_bound_ability(q.world, q.entities[it], Bound_To_1);
        }

        if player_commands[it].ability_2 {
            trigger_bound_ability(q.world, q.entities[it], Bound_To_2);
        }

        if player_commands[it].ability_3 {
            trigger_bound_ability(q.world, q.entities[it], Bound_To_3);
        }
    }
} @System(OnUpdate) @Write() @Read(Player_Commands) 

trigger_bound_ability :: (world: *World, entity: Entity, bind_tag: Type) {
    for q: iter_make_pair(world, OwnedBy, entity, GA_State_Ready, bind_tag) {
        transition_ga_state(world, q.entities[it_index], GA_State_Ready, GA_State_Triggered);
    }
}

transition_ga_state :: (world: *World, entity: Entity, from_state: Type, to_state: Type) {
    ecs_remove(world, entity, from_state);
    ecs_add(world, entity, to_state);
}

#if SERVER {
//when an ability goes off cooldown the ready tag is added, this could be any logic to indicate a gameplay ability can be clicked
ready_gameplay_ability :: (q: Query) {
    cooldowns := query_get(q, Cooldown);
    
    for 0..q.count-1 {
        if cooldowns[it].current_value <= 0 {
            ecs_add(*g_world, q.entities[it], GA_State_Ready);
        }
    }
} @System(OnUpdate) @Write() @Read(Gameplay_Ability,Cooldown) 


//activation logic for the gameplay ability goes here, could be anything but the GA_State_Triggered Tag must be removed or it will loop
activate_gameplay_ability :: (q: Query) {
    cooldowns := query_get(q, Cooldown);
    for 0..q.count-1 {
        cooldowns[it].current_value = cooldowns[it].base_value;
        
        //find all spells that are to be triggered by this gameplay_ability
        for query: iter_make_pair(q.world, TriggeredBy, q.entities[it], Spell) {
            ecs_get(q.world, query.entities[it_index], Spell).casting_entity = ecs_get_target(q.world, q.entities[it], OwnedBy);
            //workaround
            ecs_get(q.world, query.entities[it_index], Spell).debug_allow_activation = true;

            test_spell(q.world, query.entities[it_index]);
        }

        ecs_remove(q.world, q.entities[it], GA_State_Triggered);
    }
} @System(OnValidate) @Write() @Read(Gameplay_Ability,GA_State_Triggered,Cooldown) 
}