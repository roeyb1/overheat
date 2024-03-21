Player_Anim_State_Machine :: struct {
	state_list: [..] Player_Anim_State;
    
   current_state: u16;
}

Player_Anim_State :: struct {
	anim_sprites: Sprite;

	state_id: u16;

	priority: u16;

	transition_rules: [..] #type (entity: *Entity) -> bool;
}

update_state_machine :: (using state_machine: *Player_Anim_State_Machine, entity: *Entity) {
	assert(state_list.count>current_state);
	states_to_consider: [..] u16;
	states_to_consider.allocator = temp;
	for state_list[current_state].transition_rules {
		if it != null {
			if it(entity){
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
}


state_index_of:: (state_machine: Player_Anim_State_Machine,anim_state: *Player_Anim_State) -> u16{
   return cast(u16)(anim_state - state_machine.state_list.data);
}

add_state:: (using state_machine: *Player_Anim_State_Machine) -> u16{
	result := array_add(*state_list);
	for *state_list{
		array_resize(*it.transition_rules, state_list.count);
	}
	return cast(u16)(state_list.count-1);
}

