 make_anim_sm_player :: (player: *Player){
    using player.anim_statemachine;
    // array add returns a pointer to thePlayer_Anim_State at the next available index in State_List, the index is important
    // it is how the state machine refers to eachPlayer_Anim_State in the field Current_State
    idle_state := add_state(*player.anim_statemachine); //0
    movement_state := add_state(*player.anim_statemachine); //1
    attack_state := add_state(*player.anim_statemachine); //2
   
    
    state_list[idle_state].anim_sprites.sheet = get_spritesheet("assets/orc_mage_walk_2.png");
    state_list[movement_state].anim_sprites.sheet = get_spritesheet("assets/orc_mage_walk.png");
    state_list[attack_state].anim_sprites.sheet = get_spritesheet("assets/orc_mage_walk_2.png");

    state_list[idle_state].anim_sprites.time_per_frame = 0.15;
    state_list[movement_state].anim_sprites.time_per_frame = 0.15;
    state_list[attack_state].anim_sprites.time_per_frame = 0.15;

    state_list[attack_state].priority = 1;

    //idle state transitions
    state_list[idle_state].transition_rules[movement_state] = is_moving; 
    state_list[idle_state].transition_rules[attack_state] = player_is_attacking;

    //movement state transitions
    state_list[movement_state].transition_rules[idle_state] = is_not_moving;
    state_list[movement_state].transition_rules[attack_state] = player_is_attacking;

    //attack state transitions
    state_list[attack_state].transition_rules[idle_state] = player_is_not_attacking;

    

    player.anim_statemachine.current_state = idle_state;
 } 