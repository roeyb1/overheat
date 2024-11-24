Target_Entity :: struct @Component {
    target: Entity;
}

Target_Location :: struct @Component {
    value: Vector2;
}

#if SERVER{
//while a spell is gathering energy it's target location will update folowing the cursor
update_spell_targeting_while_charging :: (q: Query) {
    target_locations := query_get(q, Target_Location);

    for 0..q.count-1 {
        parent := ecs_get_target(q.world, q.entities[it], CastBy);
        if entity_is_valid(q.world, parent) {
            targeting := ecs_get(q.world, parent, Player_Commands).cursor_position;
            target_locations[it].value = targeting;
        }
    }
} @System(OnUpdate) @Write() @Read(Spell_Instance,Powering_Up,Target_Location)  
}