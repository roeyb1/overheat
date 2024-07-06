Input_States :: struct @SingletonComponent {
    #if CLIENT {
        states: [NUM_BUTTON_STATES] Key_Current_State;
        
        mouse_delta_x: int;
        mouse_delta_y: int;
        mouse_delta_z: int;
    }
}
