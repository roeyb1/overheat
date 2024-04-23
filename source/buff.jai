buff :: struct {
    duration: float;
    parameters: Table(string,float);
    function: #type (owner_stat_component: *Stats_Component, buff_instance: *buff);
}


damage_over_time :: (owner_stat_component: *Stats_Component, using buff_instance: *buff){
    damage_delta: float;

    duration = duration - g_delta_time;

    if duration < 0 {
        damage_delta = g_delta_time + duration;
    }
    else {
        damage_delta = g_delta_time;
    }

    damage_per_second,found := table_find(*parameters,"damage_per_second");
    if (found){
        print("i just took % damage\n",damage_per_second*damage_delta);
        owner_stat_component.current_health = owner_stat_component.current_health - damage_per_second*damage_delta;
    }
}

add_damage_over_time :: (target: *Player, duration: float, damage_per_second: float) {
    new_buff: buff;

    table_set(*new_buff.parameters,"damage_per_second",damage_per_second);

    new_buff.duration = duration;
    new_buff.function = damage_over_time;

    array_add(*target.buff_list, new_buff);
}

test_buff :: () -> bool {
    //test applying damage over time buff
    {
        add_damage_over_time(g_local_player,5,1000);
        add_damage_over_time(g_local_player,10,6);
        add_damage_over_time(g_local_player,3,4000000);
    }
    return true;
}
