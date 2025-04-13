Component_Storage :: struct {
    data: *void = null;
    count: s64 = 0;
    size: s64 = 0;
    component_size: s64 = 0;
    initializer: (*void) #no_context;
}

ecs_storage_row_get :: (using cs: Component_Storage, row: s64) -> *void {
    assert(row < count);
    return data + component_size * row;
}

ecs_storage_row_add :: (using cs: *Component_Storage) -> *void {
    if count >= size {
        GROWTH_FACTOR :: 2;
        new_size := GROWTH_FACTOR * size;

        if new_size < 8 then new_size = 8;

        data = realloc(data, new_size * component_size, size * component_size);
        size = new_size;
    }

    count += 1;

    ptr := data + (count - 1) * component_size;

    if initializer {
        initializer(ptr);
    } else {
        memset(ptr, 0, component_size);
    }

    return ptr;
}

ecs_storage_row_remove :: (using cs: *Component_Storage, row: s64) {
    assert(row < count);
    if count > 1 {
        memcpy(data + row * component_size, data + (count-1) * component_size, component_size);
    }
    count -= 1;
}