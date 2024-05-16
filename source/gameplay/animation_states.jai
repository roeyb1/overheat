//TODO [zak] would be nice if they could be applied to any entity type from the getgo instead of requiring an overload for each, ask roey.
/*
//TODO [zak] make a better way of establishing if a movement input was issued.
is_moving :: (entity: Player) -> bool{
        vel := get_component(*g_world, entity, Velocity);
        if vel != 0 {
            return true;
        }
        return false;
}

is_not_moving :: (entity: Player) -> bool{
    vel := get_component(*g_world, entity, Velocity);
	if vel == 0 {
		return true;
	}
	return false;
}
*/

States :: enum u8 {
    IDLE;
    WALKING;
}

Anim_State :: struct {
    current_state: States;
}

