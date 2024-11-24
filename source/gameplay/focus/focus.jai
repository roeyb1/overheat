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
    focusing: Focusing; 
    target: Target_Entity;
}

Gathered_Energy :: struct @Component {
    value: float;
}

#if SERVER{
    initialize_focus :: (world: *World, entity: Entity) {
        focus_def := ecs_get(world, entity, Focus);
        
        if focus_def {
            caster := ecs_get_target(world, entity, Child_Of);
            if entity_is_valid(world,caster) {
                focus := entity_spawn(world, parent = entity);
                ecs_add_bundle(world, focus, Focusing_Bundle.{
                    anim_list_index.value = focus_def.anim_list_index,
                    duration.base_value = focus_def.duration,
                    energy_cost.total = focus_def.energy_cost,
                    target = .{caster}
                });    
            }
        }
    } @Event(EcsOnAdd,Spell_Active)

    //this system will run while a focus exists to bind all spells that it is meant to charge to it
    bind_spells_to_focus :: (q: Query) {
        for 0..q.count-1 {
            focus := q.entities[it];
            spell := ecs_get_target(q.world, focus, Child_Of);

            if entity_is_valid(q.world, spell) {
                for * iter : iter_make_pair(q.world, Child_Of, spell, Spell_Instance, Powering_Up) {
                    for iter.entities {
                        if entity_is_valid(q.world, it){
                            if focus != ecs_get_target(q.world, it, PoweredBy) {
                                ecs_add_pair(q.world, it, PoweredBy, focus);
                            }
                        }
                    }
                }   
            }
        }
    } @System(OnUpdate) @Write() @Read(Focusing)  

    play_animation_from_focus :: (world: *World, entity: Entity) {
        parent_spell := ecs_get_target(world, entity, Child_Of);
        caster := ecs_get_target(world, parent_spell, Child_Of);

        if entity_is_valid(world, caster){
            modify_interuptor_anim_slot_from_focus(world, caster, entity);
        }          
    } @Event(EcsOnAdd,Focusing)

    //focus will drain energy from the caster while it exists
    update_focusing :: (q: Query) {
        energy_costs := query_get(q, Energy_Cost);
        targets := query_get(q, Target_Entity);
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
    } @System(OnUpdate) @Write() @Read(Focusing,Energy_Cost,Target_Entity,Gathered_Energy) 

    end_focusing :: (world: *World, entity: Entity) {
        parent := ecs_get_target(world, entity, Child_Of);
        if entity_is_valid(world, parent){
            ecs_remove(world, parent, Spell_Active);
        }          
    } @Event(EcsOnRemove,Focusing)
}
#load "focus_definitions.jai";
#load "energy_cost.jai";








