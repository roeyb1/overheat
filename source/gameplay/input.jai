Gameplay_Inputs :: enum {
    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;

    ATTACK1;
    ATTACK2;
    ATTACK3;
    ATTACK4;
    ATTACK5;

    OPEN_SKILLS_UI;
}

Input_States :: struct @SingletonComponent {
    states: [NUM_BUTTON_STATES] Key_Current_State;
    
    mouse_delta_x: int;
    mouse_delta_y: int;
    mouse_delta_z: int;
}

is_button_down :: (input_states: *Input_States, gameplay_input: Gameplay_Inputs) -> bool {
    return get_button_state(input_states, gameplay_input) & .DOWN != 0;
}

is_button_pressed :: (input_states: *Input_States, gameplay_input: Gameplay_Inputs) -> bool {
    return get_button_state(input_states, gameplay_input) & .START != 0;
}

get_button_state :: (input_states: *Input_States, gameplay_input: Gameplay_Inputs) -> Key_Current_State {
    key_code: Key_Code;
    if gameplay_input == {
        case .MOVE_UP;
            key_code = #char "w";
        case .MOVE_DOWN;
            key_code = #char "s";
        case .MOVE_LEFT;
            key_code = #char "a";
        case .MOVE_RIGHT;
            key_code = #char "d";
        case .ATTACK1;
            key_code = #char "1";
        case .ATTACK2;
            key_code = #char "2";
        case .ATTACK3;
            key_code = #char "3";
        case .ATTACK4;
            key_code = #char "4";
        case .ATTACK5;
            key_code = #char "5";    
        case .OPEN_SKILLS_UI;
            key_code = #char "k";    
    }
    return input_states.states[key_code];
}

load_input_system :: (q: Query) {
    // load the HAL inputs into the ecs.
    input_states := get_singleton(q.world, Input_States);

    for 0..input_states.states.count-1 {
        input_states.states[it] = hal_input_button_states[it];
    }
} @System(OnLoad) @Write(Input_States) @Read()