
Test_Timebased_State :: struct @Component {}

Interuptor_Anim_Slot_Bundle :: struct @Bundle {
    anim_info: Interuptor_Anim_Slot;
    test_timebased_state: Test_Timebased_State;
    duration: Duration;
}

//this should be generic ^^^, used because there is no delivery method atm
Interuptor_Anim_Slot_Bundle_sword :: struct @Bundle {
    sword: Sword;
    anim_info: Interuptor_Anim_Slot;
    test_timebased_state: Test_Timebased_State;
    duration: Duration;
}
//tmp
Interuptor_Anim_Slot_Bundle_bow :: struct @Bundle {
    bow: Bow;
    anim_info: Interuptor_Anim_Slot;
    test_timebased_state: Test_Timebased_State;
    duration: Duration;
}
//tmp
Sword :: struct @Component {
    placeholder: bool; @Sync
}
//tmp
Bow :: struct @Component {
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
                    child := spawn_child_entity(q.world, q.entities[it]);
                    add_components_from_bundle(q.world, child, Interuptor_Anim_Slot_Bundle_sword.{
                        anim_info.anim_list_index = .WIND_UP,
                    });

                }
            }
        }
    }
} @System(PreUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 

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
                    log("yummy pee");
                    child := spawn_child_entity(q.world, q.entities[it]);
                    add_components_from_bundle(q.world, child, Interuptor_Anim_Slot_Bundle_bow.{
                        anim_info.anim_list_index = .BOW_WIND_UP,
                    });

                }
            }
        }
    }
} @System(PreUpdate) @Write() @Read(Player,Player_Commands,Position,Cooldown) 

test_timebased_state :: (world: *World, entity: Entity) {
    #if SERVER {
        parent := get_parent(world, entity);
        if is_valid(world,parent){
            assert(get_component(world, parent, Player) != null);
            anim_info := get_component(world, entity, Interuptor_Anim_Slot);
            info := get_component(world,parent,Interuptor_Anim_Slot);
            info.anim_list_index = anim_info.anim_list_index;
            info.active = true;
        }
    }
} @Event(EcsOnAdd,Test_Timebased_State)

//tmp
sword_swing :: (world: *World, entity: Entity) {
    #if SERVER {
        parent := get_parent(world, entity);
        if (get_component(world,parent,Interuptor_Anim_Slot)){
            child := spawn_child_entity(world, parent);
            add_components_from_bundle(world, child, Interuptor_Anim_Slot_Bundle.{
                anim_info.anim_list_index = .ATTACK,
            });
        }
    }
} @Event(EcsOnRemove,Sword)

//tmp
bow_swing :: (world: *World, entity: Entity) {
    #if SERVER {
        parent := get_parent(world, entity);
        if (get_component(world,parent,Interuptor_Anim_Slot)){
            child := spawn_child_entity(world, parent);
            add_components_from_bundle(world, child, Interuptor_Anim_Slot_Bundle.{
                anim_info.anim_list_index = .BOW_ATTACK,
            });
        }
    }
} @Event(EcsOnRemove,Bow)












