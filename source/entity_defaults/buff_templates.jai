
add_damage_over_time :: (target: *Player, buff_duration: float, damage_per_second: float) {
    using new_stat_modification: Transitory_Stat_Modification_Per_Tick;

    duration = buff_duration;
    change_per_second = -damage_per_second;
    stat = .CURRENT_HEALTH;
    alteration_type = .ADD; 

    array_add(*target.buff_component.transitory_stat_per_tick, new_stat_modification);
}

haste :: (target: *Player, buff_duration: float, increase: float) {
    using new_stat_modification: Transitory_Stat_Modification_Constant;

    duration = buff_duration;
    value = increase;
    stat = .MOVEMENT_SPEED;
    alteration_type = .INCREASED;

    apply_stat_modification(*target.stats_component,stat,value,alteration_type);
    array_add(*target.buff_component.transitory_stat_constant, new_stat_modification); 
}