Input_States :: struct {
    states: [NUM_BUTTON_STATES] Key_Current_State;
    
    mouse_delta_x: int;
    mouse_delta_y: int;
    mouse_delta_z: int;
}

// @todo: turn this into a singleton component
g_input_states: Input_States;


load_input_system :: (world: *World) {
    // load the HAL inputs into the ecs.
    for 0..g_input_states.states.count-1 {
        g_input_states.states[it] = hal_input_button_states[it];
    }
} @System