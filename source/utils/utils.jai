#scope_export

offset_of :: ($T: Type, $member: string) -> int {
    for type_info(T).members {
        if it.name == member return it.offset_in_bytes;
    }

    assert(false, "Type '%' does not have member '%'", T, member);
    return -1;
}

test_flag_bit :: inline (flags: $T, bit: T) -> bool {
    return (flags & bit) == bit;
}

array_zero :: inline (arr: [] $T) {
    memset(arr.data, 0, arr.count * size_of(T));
}

array_append :: (arr: *[..] $T, to_append: [] T) {
    for val : to_append {
        array_add(arr, val);
    }
}

has_note :: (ti: *Type_Info_Struct, note: string) -> bool {
    for ti.notes  if it == note  return true;
    return false;
}

array_find :: (arr: [] $T, val: T, pred: (a: T, b: T) -> bool) -> bool, s64 {
    for v : arr if pred(v, val) then return true, it_index;
    return false, -1;
}

TempNew :: ($T: Type, $initialized := true) -> *T {
    memory := talloc(size_of(T));

    // Since New gets called a lot, we just roll Initialize() into here, so that
    // we don't kick off so many extra polymorphs.
    #if initialized {
        ini :: initializer_of(T);

        #if ini  inline ini(memory);
        else     memset(memory, 0, size_of(T));
    }

    return cast(*T) memory;
}

#if ENABLE_ENSURE {
    ensure :: inline (val: bool, msg: string = "", args: ..Any) -> bool {
        if !val {
            log_error("Ensure condition failed: %", tprint(msg, ..args));
            debug_break();
        }
        return val;
    }
} else {
    ensure :: inline (val: bool, msg: string = "", args: ..Any) -> bool { return val; }
}

sbprint :: print_to_builder;

#load "handle_manager.jai";
#load "timer.jai";

ENABLE_ENSURE :: true;