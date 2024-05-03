
add_damage_over_time :: (target: *Player, buff_duration: float, damage_per_second: float) {
    using new_buff: Transitory_buff;

    duration = buff_duration;
    value = -damage_per_second;
    stat = .CURRENT_HEALTH;
    alteration_type = .ADD; 

    add_transitory_buff_per_tick(target, new_buff);
}

haste :: (target: *Player, buff_duration: float, increase: float) {
    using new_buff: Transitory_buff;

    duration = buff_duration;
    value = increase;
    stat = .MOVEMENT_SPEED;
    alteration_type = .INCREASED;

    add_transitory_buff_constant(target, new_buff);
}