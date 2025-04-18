Touch :: struct @Component {
    hit_entities: [..] Entity;
}

#if SERVER {  
    //every entity that could collide should have a collider, touch should piggy back off it to size it's own
    add_touch_from_cast :: (world: *World, entity: Entity) {
        touch := cast(*Touch) ecs_add(world, entity, Touch);
        //add the collider
        BASE_COLLIDER_SIZE :: Vector2.{1., 1.};
        bounds := make_aabb(.{0,0}, BASE_COLLIDER_SIZE);
        ecs_add(world, entity, Collider_AABB.{bounds, false});
        ecs_add(world, entity, Collision_Invoker.{ id = cast(u64) entity.raw , generate_overlap_events = false });
    }

    finalise_touch_casting :: (world: *World, entity: Entity) {
        //add the caster so he cant hit himself
        if ecs_has(world, entity, Touch) {
            touch := ecs_get(world, entity, Touch);
            caster := ecs_get_target(world, entity, CastBy);
            array_add(*touch.hit_entities, caster);
            ecs_get(world, entity, Collision_Invoker).generate_overlap_events = true;
        }
    } @Event(EcsOnAdd,Active)

    //this will not only trigger for stuff that had touch, need a good way of sorting that
    touch_overlap :: (world: *World, entity: Entity) {
        overlap := ecs_get(world, entity, Overlap_Pair);
        if overlap {
            spell, target, found := get_spell_from_overlap_pair(world, overlap.a, overlap.b);
            if found {
                if valid_target_for_overlap_event(world, spell, target) {
                    cast_by := ecs_get_target(world, spell, CastBy);
                    parent_spell := ecs_get_target(world, spell, Child_Of);

                    effect := entity_spawn(world);
                    ecs_add_pair(*g_world, effect, AttachedTo, target); 
                    ecs_add_pair(*g_world, effect, AppliedTo, target); 
                    spawn_triggered_effect(world, spell, effect);
                }
            }
        }
    } @Event(EcsOnAdd,Overlap_Pair)
}

#scope_file

get_spell_from_overlap_pair :: (world: *World, a: Entity, b: Entity) -> (skill: Entity, target: Entity, found: bool) {
    if ecs_has(world, a, Spell_Instance) {
        return a,b,true;
    } 
    if ecs_has(world, b, Spell_Instance) {
        return b,a,true;
    } 

    return a,b,false;
}

//why does it require the cid bake if the value of the array is constant, cant it bake it?
valid_target_for_overlap_event :: (world: *World, skill: Entity, target: Entity) -> bool {
    if should_overlap(world, skill, target) {
        //check if the target has already been hit
        touch := ecs_get(world, skill, Touch);
        if !array_find(touch.hit_entities, target, compare_entities) {
            array_add(*touch.hit_entities,target);
            return true;
        }
    }
    return false;
}

should_overlap :: (world: *World, skill: Entity, target: Entity) -> bool {
    valid_hit_types :: Type.[ Player, Enemy ];
    return ecs_has_any(world, target, valid_hit_types);
}