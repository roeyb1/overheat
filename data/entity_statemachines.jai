 make_anim_sm_player :: (player: *Player){
    using player.anim_statemachine;
    // array add returns a pointer to thePlayer_Anim_State at the next available index in State_List, the index is important
    // it is how the state machine refers to eachPlayer_Anim_State in the field Current_State
    idle_state := add_state(*player.anim_statemachine); //0
    movement_state := add_state(*player.anim_statemachine); //1
    attack_state := add_state(*player.anim_statemachine); //2

    //load_anim_sprite(*state_list[idle_state].anim_sprites, "player1/player_idle%.png", 0.1, 8);
    //load_anim_sprite(*state_list[movement_state].anim_sprites, "player1/player_walk%.png", 0.04, 8);
    //load_anim_sprite(*state_list[attack_state].anim_sprites, "player1/player_attack%.png", 0.04, 9);
    

    state_list[idle_state].anim_sprites.sheet = load_spritesheet("assets/orc_mage_walk_2.png", 64, 0, 0);
    state_list[movement_state].anim_sprites.sheet = load_spritesheet("assets/orc_mage_walk.png", 64, 0, 0);
    state_list[attack_state].anim_sprites.sheet = load_spritesheet("assets/orc_mage_walk_2.png", 64, 0, 0);

    //state_list[idle_state].anim_sprites.z_order = cast(s8) SpriteZLayer.PLAYER;
    //state_list[movement_state].anim_sprites.z_order = cast(s8) SpriteZLayer.PLAYER;
    //state_list[attack_state].anim_sprites.z_order = cast(s8) SpriteZLayer.PLAYER;

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