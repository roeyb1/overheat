Spell :: struct @Component {
    components: [..] Type;
    triggeredby: Entity;
}

Spell_Bundle :: struct @Bundle {
    spell: Spell;
    charge_info: Charge;
    name: Name;
}

TriggeredBy :: struct @Pair { }

//when a spell is spawned into the world it will be in a state where it gathers power known as Spell_Charging, no interaction with the world.
//once a spell is fully charged or sent out for whatever reason it becomes Spell_Active and can interact with the world. 
Spell_Charging :: struct @Component {}

Spell_Active :: struct @Component {}

test_spell :: (world: *World, spell: Entity) {
    log("spell cast");
    ecs_add(world, spell, Spell_Charging);
}


initiate_charging :: (world: *World, entity: Entity) {
    charge_info := ecs_get(world, entity, Charge);
    
    charge := entity_spawn(world, parent = entity);
    ecs_add_bundle(world, charge, Charging_Bundle.{
        anim_list_index.value = charge_info.anim_list_index,
        duration.value = charge_info.duration,
        energy_cost.total = charge_info.energy_cost
    });   

    //TODO@[zak] rekon this could be done better
    gameplay_ability := ecs_get(world, entity, Spell).triggeredby;
    if (entity_is_valid(world, gameplay_ability)){
        caster := ecs_get(world, gameplay_ability, Gameplay_Ability).owner;
        if entity_is_valid(world, caster){
            modify_interuptor_anim_slot_from_charge(world, caster, charge);
        }
    }

   //ecs_remove(q.world, query.entities[it_index], Spell_Charging);       
} @Event(EcsOnAdd,Spell_Charging)

end_charging :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, Child_Of);
    if entity_is_valid(world, parent){
        to_remove := ecs_get(world, parent, Spell_Charging);

        if (to_remove) {
            ecs_remove(world, parent, Spell_Charging);
        }
    }          
} @Event(EcsOnRemove,Charging)



