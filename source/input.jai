#scope_export

Key_Code :: enum u32 #specified {
    UNKNOWN :: 0;


    // Values that map to the ascii table must be omitted from this enum as they will be used without explicit name

    ESCAPE  :: 127;
    ENTER   :: 128;
    TAB     :: 129;
    DELETE  :: 130;
    F1      :: 131;
    F2      :: 132;
    F3      :: 133;
    F4      :: 134;
    F5      :: 135;
    F6      :: 136;
    F7      :: 137;
    F8      :: 138;
    F9      :: 139;
    F10     :: 141;
    F11     :: 142;
    F12     :: 143;
    
}

Event :: struct {
    Modifier_Flags :: union {
        struct {
            shift_pressed    := false;
            ctrl_pressed     := false;
            alt_pressed      := false;
            cmd_meta_pressed := false; // Cmd on macOS, Meta on Linux
        }
        packed: u32 = 0;
    }

    type: Event_Type = Event_Type.UNINITIALIZED;

    key_pressed: u32;  // If not pressed, it's a key release.
    key_code: Key_Code = Key_Code.UNKNOWN;

    using modifier_flags: Modifier_Flags; // Only set for Event_Type.KEYBOARD.

    utf32: u32;  // If TEXT_INPUT.
    repeat := false;  // If KEYBOARD event.
    text_input_count: u16; // If KEYBOARD event that also generated TEXT_INPUT events, this will tell you how many TEXT_INPUT events after this KEYBOARD event were generated.

    wheel_delta: s32;          // Used only for mouse events.

    files: [] string;  // Used only for drag and drop events. Both the array and its contents are heap-allocated, lives until events are reset for the next frame.
}

mouse_delta_x: int;
mouse_delta_y: int;
mouse_delta_z: int;

events_this_frame:   [..] Input_Event;
input_button_states: [NUM_BUTTON_STATES] Key_Current_State;

NUM_BUTTON_STATES :: #run enum_highest_value(Key_Code) + 1;

input_system_update :: () {
    // clear any input events that were created this frame and reset delta states
    {
        for events_this_frame {
            for file: it.files {
                free(file);
            }
            array_free(it.files);
        }
        array_reset(*events_this_frame);

        /*
        mask     := ~Key_Current_State.START;
        end_mask := ~(Key_Current_State.END | .DOWN | .START);
        // @Speed: Could just keep a list of who is not currently set.
        for * input_button_states {
            if (<<it & .END) {
                <<it &= end_mask;
            } else {
                <<it &= mask;
            }
        }
        */

        mouse_delta_x = 0;
        mouse_delta_y = 0;
        mouse_delta_z = 0;
    }
}

handle_window_input_event :: (event: SDL_KeyboardEvent) {
    
}