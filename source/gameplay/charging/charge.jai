Charging :: struct @Tag {
}

Gathered_Energy :: struct @Component {
    value: float;
}

Charging_Bundle :: struct @Bundle {
    anim_list_index: Anim_List_Index; //animation that will run during the charge 
    duration: Duration; //duration component, will make the charge kill itself after a duration
    energy_cost: Energy_Cost; // needs to be put after the duration componenent @TODO we need a way of executing events in a specific order other then in the bundle this is error prone and cringe to debug
    gathered_energy: Gathered_Energy; //this is simply a tracker of how much ABSOLUTE energy was drained, it does not run any math on buffs or whatnot
    charging: Charging; //tag must be put at end so the event fires when there is data
    target: Target;
}

//TODO[@ROEY] bugged, this event triggeres twice
initiate_charging :: (world: *World, entity: Entity) {
    
    //workaround caus of the event dupe bug
    spell := ecs_get(world, entity, Spell);
    caster := ecs_get(world, entity, Spell).casting_entity;
    if entity_is_valid(world, caster){

        if (spell.debug_allow_activation){

            //spawn a charge that will absorb caster energy and generate power for the spells
            charge_info := ecs_get(world, entity, Charge);
            charge := entity_spawn(world, parent = entity);
            ecs_add_bundle(world, charge, Charging_Bundle.{
                anim_list_index.value = charge_info.anim_list_index,
                duration.value = charge_info.duration,
                energy_cost.total = charge_info.energy_cost,
                target = .{caster}
            });   

            //indicate to the charge what spell_instances it will power
            for * iter : iter_make_pair(world, Child_Of, entity) {
                for iter.entities {
                    if ecs_get(world, it, Spell_Instance) {
                        ecs_add_pair(world, it, PoweredBy, charge);
                    }  
                }
            }   

            //play the animation associated with the charge on the player
            modify_interuptor_anim_slot_from_charge(world, caster, charge);
        }
    }
    //workaround
    spell.debug_allow_activation = false;
} @Event(EcsOnAdd,Spell_Charging)

update_charging :: (q: Query) {
    energy_costs := query_get(q, Energy_Cost);
    targets := query_get(q, Target);
    gathered_energies := query_get(q, Gathered_Energy);

    for 0..q.count-1 {
        if entity_is_valid(q.world, targets[it].target){

            health_queue := ecs_get(q.world, targets[it].target, Health_Change_Queue);
            if health_queue {
                drain_energy_per_tick(health_queue,energy_costs[it]);
                
                gathered_energies[it].value += energy_costs[it].per_tick;
            }
        }
    }
} @System(OnUpdate) @Write() @Read(Charging,Energy_Cost,Target,Gathered_Energy) 

end_charging :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, Child_Of);
    if entity_is_valid(world, parent){
        to_remove := ecs_get(world, parent, Spell_Charging);

        if (to_remove) {
            ecs_remove(world, parent, Spell_Charging);
        }
    }          
} @Event(EcsOnRemove,Charging)

#load "charges.jai";
#load "energy_cost.jai";








