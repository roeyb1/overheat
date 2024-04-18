Buff_Component :: struct {
    duration: float;
    parameters: [..] float;
    function: #type (owner_stat_component: *Stats_Component,buff_component: *Buff_Component);
}


// 0 : damage_per_second
damage_over_time :: (owner_stat_component: *Stats_Component,buff_component: *Buff_Component){
    damage_delta: float;

    buff_component.duration = buff_component.duration - g_delta_time;

    if buff_component.duration < 0 {
        damage_delta = g_delta_time + buff_component.duration;
    }
    else {
        damage_delta = g_delta_time;
    }

    print("i just took % damage\n",buff_component.parameters[0]*damage_delta);
    owner_stat_component.current_health = owner_stat_component.current_health - buff_component.parameters[0]*damage_delta;
    
}

add_damage_over_time :: (target: *Player, duration: float, damage_per_second: float) {
    buff_component: Buff_Component;

    array_add(*buff_component.parameters, damage_per_second); //0

    buff_component.duration = duration;

    buff_component.function = damage_over_time;

    array_add(*target.buff_list, buff_component);
}
