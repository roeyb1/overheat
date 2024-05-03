Transitory_buff :: struct {
    duration: float;
    stat: StatType;
    value: float;
    alteration_type: AlterationType;
}

Permanent_buff :: struct {
    stat: StatType;
    value: float;
    alteration_type: AlterationType;
}

AlterationType :: enum u8 {
    INCREASED;            
    MORE;                 
    ADD;                                
}

BuffComponent :: struct {
    transitory_stat_per_tick: [..] Transitory_buff;
    transitory_stat_constant: [..] Transitory_buff;
    permanenent_stat_per_tick: [..] Permanent_buff;
    permanenet_stat_constant: [..] Permanent_buff;
}

add_transitory_buff_per_tick :: (target: *Player, buff: Transitory_buff){
    array_add(*target.buff_component.transitory_stat_per_tick, buff);
}

add_transitory_buff_constant :: (target: *Player, buff: Transitory_buff) {
    apply_buff(*target.stats_component, buff);
    array_add(*target.buff_component.transitory_stat_constant, buff);
}

apply_buff :: (stat_component: *Stats_Component, using buff: Transitory_buff, delta: float = -1.0) {
    modification_value: float;
    if delta != -1 {
        modification_value = value * delta;
    }
    else {
        modification_value = value;
    }
    
    if alteration_type == {
        case .INCREASED;
            stat_component.stats[stat].increase += modification_value;
        case .MORE;
            stat_component.stats[stat].more += modification_value;
        case .ADD;
            stat_component.stats[stat].flat_added += modification_value;
    }
    total := stat_update_total(*stat_component.stats[stat]);
    print("the stat % was changed by %, it is now %\n", stat, modification_value,total);
}

remove_buff :: (stat_component: *Stats_Component, using buff: Transitory_buff) {
    inverse_value := value * -1.0;
    if alteration_type == {
        case .INCREASED;
            stat_component.stats[stat].increase += inverse_value;
        case .MORE;
            stat_component.stats[stat].more += inverse_value;
        case .ADD;
            stat_component.stats[stat].flat_added += inverse_value;
    }
    total := stat_update_total(*stat_component.stats[stat]);
    print("the stat % was changed by %, it is now %\n",stat, inverse_value, total);
}

test_buff :: () -> bool {
    //test applying damage over time buff
    {
        add_damage_over_time(g_local_player,5,1000);
        add_damage_over_time(g_local_player,10,6);
        add_damage_over_time(g_local_player,3,40000);
        haste(g_local_player,10,0.50);
    }
    return true;
}
