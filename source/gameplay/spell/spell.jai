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

//the spell charging tag is added to a spell to indicate that the player has casted and it is now draining energy 
//and sending it as power to the instance it created
Spell_Charging :: struct @Component {}



#if SERVER{
test_spell :: (world: *World, spell: Entity) {
    
    caster := ecs_get(world, spell, Spell).casting_entity;

    spell_instance := entity_spawn(world, parent = spell);
    ecs_add_bundle(world, spell_instance, Spell_Instance_Bundle.{
        duration.value = 10.,
    });
    ecs_add_pair(*g_world, spell_instance, CastBy, ecs_get(world, spell, Spell).casting_entity); 

    fragments := ecs_get(world, spell, Fragments).components;  

    for fragments {
        ecs_add(world, spell_instance, it);
    }

    ecs_add(world, spell, Spell_Charging);

    log("hello there");
}

test_power :: (q: Query) {
    powers := query_get(q, Power);

    for 0..q.count-1 {
       //log("%", powers[it].total);
    }

    
} @System(OnUpdate) @Write() @Read(Spell_Instance,Power)  

activate_spell_instance :: (world: *World, entity: Entity) {
    for * iter : iter_make_pair(world, Child_Of, entity, Spell_Instance,Powering_Up) {
        for iter.entities {
            ecs_remove(world, it, Powering_Up);
            ecs_add(world, it, Active);
        }
    }   
} @Event(EcsOnRemove,Spell_Charging)
}

#load "spell_fragments/fragments.jai";
#load "spell_instance.jai";
#load "size.jai";

