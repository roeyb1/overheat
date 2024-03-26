#scope_export

NULL_HANDLE :: 0;

HandleManager :: struct {
    free_handles: [..] u32;
    transient_handles: [..] u32;
    next_free_handle: u32 = 1; // start at 1, 0 indicates null
    max_handle: u32 = U32_MAX;
}

is_valid_handle :: (using manager: *HandleManager, handle: u32) -> bool {
    // additional checks in debug builds
    #if DEBUG {
        // not yet allocated:
        if handle >= next_free_handle {
            return false;
        }

        if array_find(free_handles, handle) {
            return false;
        }
    }
    return handle != 0;
}

alloc_handle :: (using manager: *HandleManager, transient: bool = false) -> u32 {
    result: u32 = 0;
    if free_handles.count > 0 {
        result = pop(*free_handles);
    } else if next_free_handle <= max_handle {
        result = next_free_handle;
        next_free_handle += 1;
    }

    if transient && result > 0 {
        array_add(*transient_handles, result);
    }

    return result;
}

free_handle :: (using manager: *HandleManager, handle: u32) {
    if handle != 0 {
        array_add(*free_handles, handle);
    }
}