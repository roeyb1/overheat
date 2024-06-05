/** Stores component data for a single component type in contiguous memory blocks */
Component_Container :: struct {
    /** Pointer to the start of the component memory */
    data: *void = null;

    /** Current number of allocated components */
    count: s64 = 0;

    /** Maximum number of things we can store before reallocating the data pointer */ 
    size: s64 = 0;

    component_size: s64 = 0;

    initializer: (*void);
}

Component_Type_ID :: struct {
    hash: u64;
    runtime_size: s64;
    debug_name: string;
    initializer: (*void);
}

operator== :: (a: Component_Type_ID, b: Component_Type_ID) -> bool {
    return a.hash == b.hash;
}

/** Get the type id of a component. Just hash the component type name. */
component_type_id :: ($c: Type) -> Component_Type_ID {
    assert(type_info(c).type == .STRUCT, "Only struct types are supported as component types!");

    ti :: type_info(c);
    hash :: #run fnv1a_hash(ti.name.data, ti.name.count, h = 5381);
    return .{hash, ti.runtime_size, ti.name, ti.initializer};
}

get_component :: (cc: *Component_Container, row: s64) -> *void {
    return cc.data + cc.component_size * row;
}

add_row :: (cc: *Component_Container) -> *void {
    if cc.count >= cc.size {
        GROWTH_FACTOR :: 2;
        new_size := GROWTH_FACTOR * cc.count;

        if new_size < 8 then new_size = 8;
        cc.data = realloc(cc.data, new_size * cc.component_size, cc.size * cc.component_size);

        cc.size = new_size;
    }

    cc.count += 1;

    data := cc.data + (cc.count - 1) * cc.component_size;

    if cc.initializer {
        cc.initializer(data);
    } else {
        memset(data, 0, cc.component_size);
    }

    return data;
}

remove_row :: (cc: *Component_Container, row: s64) {
    if cc.count > 1 {
        // swap the removed position with the last element
        memcpy(cc.data + row * cc.component_size, cc.data + (cc.count-1) * cc.component_size, cc.component_size);
    }
    cc.count -= 1;
}

#import "Hash";
