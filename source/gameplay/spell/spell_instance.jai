Spell_Instance :: struct @Tag {}

//when a spell instance is spawned into the world it will be in a state where it gathers power known as Powering_Up, no interaction with the world.
//once a spell is fully charged or sent out for whatever reason it becomes Active and can interact with the world. 
Powering_Up :: struct @Tag {}
Active :: struct @Tag {}

Spell_Instance_Bundle :: struct @Bundle {
    power: Power; 
    energy_change_queue: Energy_Change_Queue; 
    position: Position;
    spell_instance: Spell_Instance;
    fragment_storage: Fragment_Storage;
    networking_id: Networked;
    duration: Duration;
}

CastBy :: struct @Pair {}

#if SERVER {
    spawn_triggered_spell_instance :: (world: *World, from: Entity, to: Entity) {
        //first all the apropriate relationships will be propagated to the triggered spell
        cast_by := ecs_get_target(world, from, CastBy);
        if entity_is_valid(world, cast_by) {
            ecs_add_pair(world, to, CastBy, cast_by);
        }

        parent_spell := ecs_get_target(world, from, Child_Of);
        if entity_is_valid(world, parent_spell) {
            ecs_add_pair(world, to, Child_Of, parent_spell);
        }

        from_fragments := ecs_get(world, from, Fragment_Storage);
        assert(from_fragments != null);
        
        //then all the components that are to be propageted baseline, special propagation can be handled case by case 
        power := ecs_get(world, from, Power); 
        position := ecs_get(world, from, Position);

        assert(power != null);
        assert(position != null);

        //initialise the new entity
        ecs_add_bundle(world, to, Spell_Instance_Bundle.{
            duration.base_value = 5, //temporary not all spells should have a duration some will likely have their own termination condition
            power = power,
            position = position,
            fragment_storage = make_child_fragments(from_fragments.payload),
        });
    }
}
