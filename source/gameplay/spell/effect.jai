Effect :: struct @Component {
}

Effect_Bundle :: struct @Bundle {
    power: Power; 
    networking_id: Networked;
    fragment_storage: Fragment_Storage;
    effect: Effect;
    position: Position;
    active: Active;
    duration: Duration;
}

AppliedTo :: struct @Pair { }

//an effect is an entity that gets initialized when components such as HASTE get added to a vector. it will create the effect which will then be 
//attached to the intended target, once it's attached it will run it's course and do whatever is in the HASTE system 
#if SERVER {
    spawn_triggered_effect :: (world: *World, from: Entity, to: Entity) {
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
        //[TODO] some validation here would be needed

        //finally initialise the new entity
        ecs_add_bundle(world, to, Effect_Bundle.{
            duration.base_value = 5, //temporary not all spells should have a duration some will likely have their own termination condition
            power = power,
            position = position,
            fragment_storage = make_child_fragments(from_fragments.payload),
        });
    }
}