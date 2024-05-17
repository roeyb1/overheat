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

#load "handle_manager.jai";
