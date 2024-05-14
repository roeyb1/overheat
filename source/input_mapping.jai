Keymap_Action_Info :: struct {
    action_name:    string;
    proc:           #type (key_state: Key_Current_State) -> ();
}
Key_Mapping :: struct {
    key_code:       Key_Code;
    modifier_flags: Modifier_Flags;
    action_info:    *Keymap_Action_Info;
}

Keymap :: struct {
    mappings:   [..] Key_Mapping;
    actions:    [..] Keymap_Action_Info;
}

global_key_map: Keymap;

input_map_init:: () {
    log("Input Manager initializing...");

    register_all_input_actions(*global_key_map);
    load_key_mappings_from_file("config/keymap.txt");

    log("Input Manager initialized");
}

input_map_update :: () {
    for global_key_map.mappings {
        // check that it's either down or start, sometimes key states reset between frames and end up restarting even though they were held...
        input_state := check_input_state(it.key_code, it.modifier_flags);
        if input_state != .NONE {
            if !it.action_info.proc {
                log_error("Action '%' has no function bound!", it.action_info.action_name);
                continue;
            }
            it.action_info.proc(input_state);
        }
    }
}

input_map_shutdown :: () {
    // nothing required atm
    log("Input manager shutdown successfully");
}

#scope_file

load_key_mappings_from_file :: (filename: string) -> bool{
    handler: Text_File_Handler;
    defer deinit(*handler);

    start_file(*handler, "keymap", filename, false);
    if handler.failed {
        return false;
    }

    while true {
        line, cont := consume_next_line(*handler);
        if !cont break;

        key_binding, rhs := break_by_spaces(line);
        if !rhs {
            error(handler, "Expected a space between the keymap and the action");
            return false;
        }

        mapping: Key_Mapping;
        for *global_key_map.actions {
            if it.action_name == rhs {
                mapping.action_info = it;
            }
        }
        if mapping.action_info == null {
            error(handler, "Unknown input action found %!", rhs);
            continue;
        }

        modifier_flags, key_code, success := parse_key_binding(handler, key_binding);
        if !success {
            return false;
        }

        mapping.key_code = xx key_code;
        mapping.modifier_flags = modifier_flags;
        array_add(*global_key_map.mappings, mapping);
    }

    return true;
}

check_input_state :: (key_code: Key_Code, modifiers: Modifier_Flags) -> Key_Current_State {
    key_state := input_button_states[key_code];
    shift_state := input_button_states[Key_Code.SHIFT];
    ctrl_state := input_button_states[Key_Code.CTRL];
    alt_state := input_button_states[Key_Code.ALT];

    if key_state == .NONE {
        return key_state;
    }

    if modifiers.shift_pressed {
        if shift_state == .NONE {
            key_state = .NONE;
        }
    } else {
        if shift_state != .NONE {
            key_state = .NONE;
        }
    }

    if modifiers.alt_pressed {
        if alt_state == .NONE {
            key_state = .NONE;
        }
    } else {
        if alt_state != .NONE {
            key_state = .NONE;
        }
    }

    if modifiers.ctrl_pressed {
        if ctrl_state == .NONE {
            key_state = .NONE;
        }
    } else {
        if ctrl_state != .NONE {
            key_state = .NONE;
        }
    }

    return key_state;
}

parse_key_binding :: (handler: Text_File_Handler, key_binding: string) -> Modifier_Flags, Key_Code, bool {
    modifier_flags: Modifier_Flags;

    // make a copy of the string view so we can advance the data pointer
    key_string := key_binding;
    // parse all the modifiers:
    while true {
        // if the count is less than 2 we cannot possibly have a modifier here
        if key_string.count < 2 break;
        // if the second char isn't a dash, this also can't be a modifier
        if key_string[1] != #char "-" break;

        mod_char := key_string[0];
        advance(*key_string, 2);

        if mod_char == #char "S" {
            modifier_flags.shift_pressed = true;
        } else if mod_char == #char "C" {
            modifier_flags.ctrl_pressed = true;
        } else if mod_char == #char "A" {
            modifier_flags.alt_pressed = true;
        } else {
            error(handler, "Unknown modifier key %", key_string);
            return modifier_flags, 0, false;
        }
    }


    if key_string.count == 0 {
        error(handler, "Missing keycode after modifier flags.");
        return modifier_flags, 0, false;
    }

    key_code: Key_Code;
    if key_string == {
        case "Space";   key_code = .SPACEBAR;
        case "Esc";     key_code = .ESCAPE;
        case "Enter";   key_code = .ENTER;
        case "Tab";     key_code = .TAB;
        case "MB1";     key_code = .MOUSE_BUTTON_LEFT;
        case "MB2";     key_code = .MOUSE_BUTTON_RIGHT;
        case;           key_code = .UNKNOWN;
        // @todo: Function keys
    }


    if key_code != .UNKNOWN {
        return modifier_flags, key_code, true;
    }

    // only single-char keys are possible
    // if the char is uppercase, we have to make it lower since the keycodes map numerically to the lowercase characters
    key_char: u32 = xx to_lower(key_string[0]);

    // single char codes can only be letter or digit.
    assert((key_char >= #char "a" && key_char <= #char "z")
        || (key_char >= #char "0" && key_char <= #char "9"));

    return modifier_flags, cast(Key_Code) key_char, true;
}

#import "System";
#import "Text_File_Handler";
#import "String";