//spells live in the players spell inventory and contain the information required to cast spell_instances
Spell :: struct @Component {
    casting_entity: Entity;
    debug_allow_activation: bool;
}

Spell_Bundle :: struct @Bundle {
    spell: Spell;
    focus_info: Focus;
    name: Name;
    fragments: Fragments;
}

TriggeredBy :: struct @Pair { }

//when a spell is spawned into the world it will be in a state where it gathers power known as Spell_Focusing, no interaction with the world.
//once a spell is fully focused or sent out for whatever reason it becomes Spell_Active and can interact with the world. 
Spell_Focusing :: struct @Component {}

Spell_Active :: struct @Component {}

#if SERVER {
cast_spell :: (world: *World, spell: Entity) {
    
    caster := ecs_get(world, spell, Spell).casting_entity;

    spell_instance := entity_spawn(world, parent = spell);
    ecs_add_bundle(world, spell_instance, Spell_Instance_Bundle.{
        duration.base_value = 6.,
    });
    ecs_add_pair(*g_world, spell_instance, CastBy, ecs_get(world, spell, Spell).casting_entity);   

    ecs_add(world, spell, Spell_Focusing);
}

test_power :: (q: Query) {
    powers := query_get(q, Power);

    for 0..q.count-1 {
       log("%", powers[it].total);
    }
} @System(OnUpdate) @Write() @Read(Spell_Instance,Power)  
}

#load "fragments.jai";
#load "spell_instance.jai";


