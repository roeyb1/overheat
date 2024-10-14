
//spells live in the players spell inventory and contain the information required to cast spell_instances
Spell :: struct @Component {
}

Spell_Bundle :: struct @Bundle {
    spell: Spell;
    focus_info: Focus;
    name: Name;
    spell_dormant: Spell_Dormant;
    fragments: Fragment_Storage;
}

CastFrom :: struct @Pair { }

//the spell charging tag is added to a spell to indicate that the player has casted and it is now draining energy 
//and sending it as power to the instance it created
Spell_Active :: struct @Component {}
Spell_Waiting :: struct @Component {
    waiting := true;
}
Spell_Dormant :: struct @Component {}



#if SERVER{
    cast_spell :: (world: *World, spell: Entity) {
        if ecs_get(world, spell, Spell_Dormant){
            caster := ecs_get_target(world, spell, Child_Of);

            spell_instance := entity_spawn(world, parent = spell);
            
            ecs_add_pair(*g_world, spell_instance, InheritFragmentsFrom, spell);
            ecs_add_pair(*g_world, spell_instance, CastBy, caster); 

            ecs_add_bundle(world, spell_instance, Spell_Instance_Bundle.{
                duration.base_value = 5,
                position.value = ecs_get(world, caster, Position).value,
            });

            ecs_remove(world, spell, Spell_Dormant);
            ecs_add(world, spell, Spell_Waiting);
        }
    }

    //will mark all inactive spell instances spawned by spells as ready to be powered, spell will fire once all are spawned
    charge_spell_instances :: (q: Query) {
        spell_waiting := query_get(q, Spell_Waiting);

        for query_index : 0..q.count-1 {

            spell_waiting[query_index].waiting = false;

            //here we add powering up to all the spell instances
            for *iter: iter_make_pair(q.world, Child_Of, q.entities[query_index], Spell_Instance) {
                for iter.entities {
                    if !ecs_get(q.world,it, Active) && !ecs_get(q.world,it, Powering_Up){
                        ecs_add(q.world, it, Powering_Up);
                        spell_waiting[query_index].waiting = true;
                    }
                }
            }
            if !spell_waiting[query_index].waiting {
                ecs_remove(q.world, q.entities[query_index], Spell_Waiting);
                ecs_add(q.world, q.entities[query_index], Spell_Active);
            }
        }
    } @System(OnUpdate) @Write(Spell_Waiting) @Read()  

    test_power :: (q: Query) {
        powers := query_get(q, Power);

        for 0..q.count-1 {
        //log("entity % has % power", q.entities[it],powers[it].total);
        }

        
    } @System(OnUpdate) @Write() @Read(Spell_Instance,Power)   

    finalise_spell_casting :: (world: *World, entity: Entity) {
            for * iter : iter_make_pair(world, Child_Of, entity, Spell_Instance,Powering_Up) {
                    for iter.entities {
                        if entity_is_valid(world, it) {
                            ecs_remove(world, it, Powering_Up);
                            ecs_add(world, it, Active);
                        }
                    }
            }  
            ecs_add(world, entity, Spell_Dormant);
    } @Event(EcsOnRemove,Spell_Active)
}

#load "spell_fragments/fragments.jai";
#load "spell_instance.jai";
#load "size.jai";
#load "effect.jai";
