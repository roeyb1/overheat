//spells live in the players spell inventory and contain the information required to cast spell_instances
Spell :: struct @Component {
    casting_entity: Entity;
    debug_allow_activation: bool;
}

Spell_Bundle :: struct @Bundle {
    spell: Spell;
    charge_info: Charge;
    name: Name;
    fragments: Fragments;
}

TriggeredBy :: struct @Pair { }

//when a spell is spawned into the world it will be in a state where it gathers power known as Spell_Charging, no interaction with the world.
//once a spell is fully charged or sent out for whatever reason it becomes Spell_Active and can interact with the world. 
Spell_Charging :: struct @Component {}

Spell_Active :: struct @Component {}

#if SERVER{
test_spell :: (world: *World, spell: Entity) {
    
    caster := ecs_get(world, spell, Spell).casting_entity;

    spell_instance := entity_spawn(world, parent = spell);
    ecs_add_bundle(world, spell_instance, Spell_Instance_Bundle.{
        duration.base_value = 6.,
    });
    ecs_add_pair(*g_world, spell_instance, CastBy, ecs_get(world, spell, Spell).casting_entity);   

    ecs_add(world, spell, Spell_Charging);
}


//TODO[@ROEY] bugged, this event triggeres twice
//this goes elsewhere
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
}

debug_power :: (q: Query) {
    powers := query_get(q, Power);

    for 0..q.count-1 {
       log("%", powers[it].total);
    }
} @System(OnUpdate) @Write() @Read(Spell_Instance,Power)  

#load "fragments.jai";
#load "spell_instance.jai";


