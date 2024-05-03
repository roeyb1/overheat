

Transitory_Stat_Modification_Per_Tick :: struct {
    duration: float;
    change_per_second: float;
    stat: StatType;
    alteration_type: AlterationType;
}

Transitory_Stat_Modification_Constant :: struct {
    duration: float;
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
    transitory_stat_per_tick: [..] Transitory_Stat_Modification_Per_Tick;
    transitory_stat_constant: [..] Transitory_Stat_Modification_Constant;
}

add_transitory_stat_modification_per_tick :: (target: *Player, duration: float, stat: StatType, change_per_second: float, alteration_type: AlterationType = .ADD){
    modification := Transitory_Stat_Modification_Per_Tick.{duration,change_per_second,stat,alteration_type};

    array_add(*target.buff_component.transitory_stat_per_tick,modification);
}

add_transitory_stat_modification_constant :: (target: *Player, duration: float, stat: StatType, value: float, alteration_type: AlterationType) {
    modification := Transitory_Stat_Modification_Constant.{duration, stat, value, alteration_type};

    array_add(*target.buff_component.transitory_stat_constant,modification);
}

apply_stat_modification :: (stat_component: *Stats_Component, stat: StatType, value: float, alteration_type: AlterationType) {
    if alteration_type == {
        case .INCREASED;
            stat_component.stats[stat].increase += value;
        case .MORE;
            stat_component.stats[stat].more += value;
        case .ADD;
            stat_component.stats[stat].flat_added += value;
    }
    total := stat_update_total(*stat_component.stats[stat]);
    print("the stat % was changed by %, it is now %\n",stat,value,total);
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
