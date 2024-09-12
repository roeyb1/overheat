//spells live in the players spell inventory and contain the information required to cast spell_instances
Spell :: struct @Component {
    casting_entity: Entity;
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

test_spell :: (world: *World, spell: Entity) {
    

    spell_instance := entity_spawn(world);
    ecs_add_bundle(world, spell_instance, Spell_Instance_Bundle.{
        duration.base_value = 6.,
    });
    ecs_add_pair(*g_world, spell_instance, CastBy, ecs_get(world, spell, Spell).casting_entity);   

    ecs_add(world, spell, Spell_Charging);
}

//TODO@[ZAK] attatch the charge to the player

//this goes elsewhere
initiate_charging :: (world: *World, entity: Entity) {
    charge_info := ecs_get(world, entity, Charge);
    
    charge := entity_spawn(world, parent = entity);
    ecs_add_bundle(world, charge, Charging_Bundle.{
        anim_list_index.value = charge_info.anim_list_index,
        duration.value = charge_info.duration,
        energy_cost.total = charge_info.energy_cost
    });   

    
    caster := ecs_get(world, entity, Spell).casting_entity;
    if entity_is_valid(world, caster){
        modify_interuptor_anim_slot_from_charge(world, caster, charge);
    }
} @Event(EcsOnAdd,Spell_Charging)

update_charging :: (q: Query) {
    energy_costs := query_get(q, Energy_Cost);

    for 0..q.count-1 {
        parent := ecs_get_target(q.world, q.entities[it], Child_Of);
        if entity_is_valid(q.world, parent){
            spell := ecs_get(q.world, parent, Spell);
            casting_entity := spell.casting_entity;
            health_queue := ecs_get(q.world, casting_entity, Health_Change_Queue);
            if health_queue {
                drain_energy_per_tick(health_queue,energy_costs[it]);
                
                //for now this lives here but eventually each charge could update it's power in a system
                gather_power(q.world,casting_entity,5.);
            }
        }
    }
} @System(OnUpdate) @Write() @Read(Charging,Energy_Cost) 

end_charging :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, Child_Of);
    if entity_is_valid(world, parent){
        to_remove := ecs_get(world, parent, Spell_Charging);

        if (to_remove) {
            ecs_remove(world, parent, Spell_Charging);
        }
    }          
} @Event(EcsOnRemove,Charging)

#load "fragments.jai";
#load "spell_instance.jai";


