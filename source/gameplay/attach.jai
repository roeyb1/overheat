AttachedTo :: struct @Pair { }

#if SERVER{
update_position_from_attached:: (q: Query) {
        positions := query_get(q, Position);

        for effects : 0..q.count-1 {
            attached_to := ecs_get_target(q.world, q.entities[effects], AttachedTo);
            if entity_is_valid(q.world, attached_to) {
                position := ecs_get(q.world, attached_to, Position);
                if position {
                    positions[effects] = position;
                }
            }
        }
} @System(OnUpdate) @Write(Position) @Read() 
}