is_moving :: (entity: *Entity) -> bool{
	if length(entity.velocity) > 0 {
		return true;
	}
	return false;
}

is_not_moving :: (entity: *Entity) -> bool{
	if length(entity.velocity) == 0 {
		return true;
	}
	return false;
}

player_is_attacking :: (entity: *Entity) -> bool{
		if EntityCast(entity, Player).is_attacking{
			return true;
		}
		return false;
}

player_is_not_attacking :: (entity: *Entity) -> bool{
		if !EntityCast(entity, Player).is_attacking{
			return true;
		}
		return false;
}