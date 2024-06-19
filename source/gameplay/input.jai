Gameplay_Inputs :: enum {
    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;
    
    MAIN_ATTACK;
    SECONDARY_ATTACK;
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
        case .MAIN_ATTACK;
            key_code = Key_Code.MOUSE_BUTTON_LEFT;
        case .SECONDARY_ATTACK;
            key_code = Key_Code.MOUSE_BUTTON_RIGHT;
    }
    return input_states.states[key_code];
}

load_input_system :: (world: *World) {
    // load the HAL inputs into the ecs.
    input_states := get_singleton(world, Input_States);

    for 0..input_states.states.count-1 {
        input_states.states[it] = hal_input_button_states[it];
    }
} @System @OnLoad