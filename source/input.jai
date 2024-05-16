#scope_export

Key_Code :: enum u32 #specified {
    UNKNOWN :: 0;


    // Values that map to the ascii table must be omitted from this enum as they will be used without explicit name
    // Except spacebar, which is the first ascii character
    SPACEBAR :: 32;

    ESCAPE    :: 127;
    ENTER     :: 128;
    TAB       :: 129;
    BACKSPACE :: 130;

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

    MOUSE_BUTTON_LEFT   :: 144;
    MOUSE_BUTTON_RIGHT  :: 145;
    MOUSE_BUTTON_MIDDLE :: 146;

    SHIFT   :: 147;
    CTRL    :: 148;
    ALT     :: 149;
    SUPER   :: 150;
}

Key_Current_State :: enum_flags {
    NONE    :: 0x0;
    DOWN    :: 0x1;
    START   :: 0x4;
    END     :: 0x8;
}

Event_Type :: enum u32 {
    UNINITIALIZED       :: 0;
    KEYBOARD            :: 1;
    TEXT_INPUT          :: 2;
    WINDOW              :: 3;
    MOUSE_WHEEL         :: 4;
    DRAG_AND_DROP_FILES :: 5;
}

Modifier_Flags :: union {
    struct {
        shift_pressed   := false;
        ctrl_pressed    := false;
        alt_pressed     := false;
        super_pressed   := false; // Cmd on macOS, Meta on Linux
    }
    packed: u32 = 0;
}

Input_Event :: struct {
    type: Event_Type = Event_Type.UNINITIALIZED;

    key_pressed: bool;  // If not pressed, it's a key release.
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

        // Remove all the .START flags that were added this frame
        mask     := ~Key_Current_State.START;

        // Remove all flags from any Key up events
        end_mask := ~(Key_Current_State.END | .DOWN | .START);

        // @Speed: Could just keep a list of who is not currently set.
        for * input_button_states {
            if (<<it & .END) {
                <<it &= end_mask;
            } else {
                <<it &= mask;
            }
        }

        mouse_delta_x = 0;
        mouse_delta_y = 0;
        mouse_delta_z = 0;
    }
}

handle_window_input_event :: (sdl_event: *SDL_Event) {
    event: Input_Event;

    if sdl_event.type == {
        // on focus lost, drop all keys as if we released everything this frame
        case SDL_WINDOWEVENT;
            if sdl_event.window.event == SDL_WINDOWEVENT_FOCUS_LOST {
                release_all_keys();
            }
        case SDL_MOUSEWHEEL;
            event.type = .MOUSE_WHEEL;

            event.wheel_delta = sdl_event.wheel.y;

        case SDL_MOUSEBUTTONDOWN;
            event.type = .KEYBOARD;

            if sdl_event.button.button == SDL_BUTTON_LEFT   then event.key_code = .MOUSE_BUTTON_LEFT;
            if sdl_event.button.button == SDL_BUTTON_RIGHT  then event.key_code = .MOUSE_BUTTON_RIGHT;
            if sdl_event.button.button == SDL_BUTTON_MIDDLE then event.key_code = .MOUSE_BUTTON_MIDDLE;

            input_button_states[event.key_code] = ifx sdl_event.button.state == SDL_PRESSED then .START | .DOWN else .END | .DOWN;

        case SDL_TEXTINPUT;
            event.type = .TEXT_INPUT;

            //assert(false, "we don't support text input yet");
        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            event.type = .KEYBOARD;

            sdl_key := sdl_event.key.keysym.sym;

            event.key_code = sdl_sym_to_key_code(sdl_key);
            event.key_pressed = (sdl_event.type == SDL_KEYDOWN);
            event.repeat = sdl_event.key.repeat != 0;

            input_button_states[event.key_code] = ifx event.key_pressed then .START | .DOWN else .END | .DOWN;

            kmod := SDL_GetModState();
            event.modifier_flags.shift_pressed = ((kmod & KMOD_SHIFT) != 0);
            event.modifier_flags.ctrl_pressed  = ((kmod & KMOD_CTRL) != 0);
            event.modifier_flags.alt_pressed   = ((kmod & KMOD_ALT) != 0);
            event.modifier_flags.super_pressed = ((kmod & KMOD_GUI) != 0);

            update_modifier_keys(event.modifier_flags);
        case;
            return;
    }
    array_add(*events_this_frame, event);
}

release_all_keys :: () {
    for * input_button_states {
        << it = Key_Current_State.NONE;
    }
}

#scope_file

sdl_sym_to_key_code :: (sdl_sym: SDL_Keycode) -> Key_Code {
    if sdl_sym > 32 && sdl_sym < 127 {
        return cast(Key_Code)sdl_sym;
    }

    if sdl_sym == {
        case SDLK_ESCAPE;
            return .ESCAPE;
        case SDLK_RETURN;
            return .ENTER;
        case SDLK_TAB;
            return .TAB;
        case SDLK_BACKSPACE;
            return .BACKSPACE;
        case SDLK_F1;
            return .F1;
        case SDLK_F2;
            return .F2;
        case SDLK_F3;
            return .F3;
        case SDLK_F4;
            return .F4;
        case SDLK_F5;
            return .F5;
        case SDLK_F6;
            return .F6;
        case SDLK_F7;
            return .F7;
        case SDLK_F8;
            return .F8;
        case SDLK_F9;
            return .F9;
        case SDLK_F10;
            return .F10;
        case SDLK_F11;
            return .F11;
        case SDLK_F12;
            return .F12;
    }

    return 0;
}

update_modifier_keys :: inline (mods: Modifier_Flags) {
    // If a modifier key wasn't already pressed, ensure that it is in the .START | .DOWN states
    if mods.shift_pressed && !(input_button_states[Key_Code.SHIFT] & .DOWN) {
        input_button_states[Key_Code.SHIFT] = .START | .DOWN;
    } else if !mods.shift_pressed && (input_button_states[Key_Code.SHIFT] & .DOWN) {
        input_button_states[Key_Code.SHIFT] |= .END;
    }
    if mods.ctrl_pressed && !(input_button_states[Key_Code.CTRL] & .DOWN) {
        input_button_states[Key_Code.CTRL] = .START | .DOWN;
    } else if !mods.ctrl_pressed && (input_button_states[Key_Code.CTRL] & .DOWN) {
        input_button_states[Key_Code.CTRL] |= .END;
    }
    if mods.alt_pressed && !(input_button_states[Key_Code.ALT] & .DOWN) {
        input_button_states[Key_Code.ALT] = .START | .DOWN;
    } else if !mods.alt_pressed && (input_button_states[Key_Code.ALT] & .DOWN) {
        input_button_states[Key_Code.ALT] |= .END;
    }
    if mods.super_pressed && !(input_button_states[Key_Code.SUPER] & .DOWN) {
        input_button_states[Key_Code.SUPER] = .START | .DOWN;
    } else if !mods.super_pressed && (input_button_states[Key_Code.SUPER] & .DOWN) {
        input_button_states[Key_Code.SUPER] |= .END;
    }
}
