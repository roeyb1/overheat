update_player_state :: (world: *World) {
    for Query(Player,*Anim_State).{world = world} {
        using it.anim_state;
        print("current state is % \n", current_state);
        if current_state == {
            case .IDLE;
                vel := get_component(*g_world, it_index, Velocity);
                if (length(vel) != 0) {
                    current_state = .WALKING;
                }
                break;
            case .WALKING;
                vel := get_component(*g_world, it_index, Velocity);
                if (length(vel) == 0) {
                    current_state = .IDLE;
                }
                break;
        }
    }
} @System





/*

Anim_State_Machine :: struct {
    state_list: [..] Anim_State;
    
   current_state: u16;
}

Anim_State :: struct {
	anim_sprites: Sprite;

	state_id: u16;

	priority: u16;

	transition_rules: [..] #type (entity: Player) -> bool;
}

update_player_state_machine :: (world: *World) {
    for Query(Player,*Anim_State_Machine,*Sprite).{world = world} {
        using it.anim_state_machine;

        assert(state_list.count>current_state);
        states_to_consider: [..] u16;
        states_to_consider.allocator = temp;
        
        for state : state_list[current_state].transition_rules {
            if state != null {
                if state(it.player){
                    array_add(*states_to_consider, cast(u16)it_index);
                }
                
            }
        }
        
        if (states_to_consider.count == 0) then return;

        current_highest := states_to_consider[0];
        for states_to_consider{
            if state_list[it].priority > state_list[current_highest].priority then current_highest = it;
        }

        current_state = current_highest;
        player.sprite = state_list[current_state].anim_sprites;
    }
}


state_index_of:: (state_machine: Anim_State_Machine,anim_state: *Anim_State) -> u16{
   return cast(u16)(anim_state - state_machine.state_list.data);
}

add_state:: (using state_machine: *Anim_State_Machine) -> u16{
	result := array_add(*state_list);
	for *state_list{
		array_resize(*it.transition_rules, state_list.count);
	}
	return cast(u16)(state_list.count-1);
}

*/