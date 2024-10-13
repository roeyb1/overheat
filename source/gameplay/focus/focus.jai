Focus :: struct @Component {
    energy_cost: float;
    duration: float;
    anim_list_index: Anim_List_Indecies;
} 

Focusing :: struct @Tag {
}

Focusing_Bundle :: struct @Bundle {
    anim_list_index: Anim_List_Index; //animation that will run during the focus 
    duration: Duration; //duration component, will make the focus kill itself after a duration
    energy_cost: Energy_Cost; // needs to be put after the duration componenent @TODO we need a way of executing events in a specific order other then in the bundle this is error prone and cringe to debug
    gathered_energy: Gathered_Energy; //this is simply a tracker of how much ABSOLUTE energy was drained, it does not run any math on buffs or whatnot
    focusing: Focusing; //tag must be put at end so the event fires when there is data
    target: Target;
}

Gathered_Energy :: struct @Component {
    value: float;
}

//TODO[@ROEY] bugged, this event triggeres twice
initiate_focusing :: (world: *World, entity: Entity) {
    
    //workaround caus of the event dupe bug
    spell := ecs_get(world, entity, Spell);
    caster := ecs_get(world, entity, Spell).casting_entity;
    if entity_is_valid(world, caster){

        if (spell.debug_allow_activation){

            //spawn a focus that will absorb caster energy and generate power for the spells
            focus_info := ecs_get(world, entity, Focus);
            focus := entity_spawn(world, parent = entity);
            ecs_add_bundle(world, focus, Focusing_Bundle.{
                anim_list_index.value = focus_info.anim_list_index,
                duration.base_value = focus_info.duration,
                energy_cost.total = focus_info.energy_cost,
                target = .{caster}
            });   

            //indicate to the focus what spell_instances it will power
            for * iter : iter_make_pair(world, Child_Of, entity) {
                for iter.entities {
                    if ecs_get(world, it, Spell_Instance) {
                        ecs_add_pair(world, it, PoweredBy, focus);
                    }  
                }
            }   

            //play the animation associated with the focus on the player
            modify_interuptor_anim_slot_from_focus(world, caster, focus);
        }
    }
    //workaround
    spell.debug_allow_activation = false;
} @Event(EcsOnAdd,Spell_Focusing)

update_focusing :: (q: Query) {
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
} @System(OnUpdate) @Write() @Read(Focusing,Energy_Cost,Target,Gathered_Energy) 

end_focusing :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, Child_Of);
    if entity_is_valid(world, parent){
        to_remove := ecs_get(world, parent, Spell_Focusing);

        if (to_remove) {
            ecs_remove(world, parent, Spell_Focusing);
        }
    }          
} @Event(EcsOnRemove,Focusing)

#load "foci.jai";
#load "energy_cost.jai";








