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
    is_singleton: bool;
}

operator== :: (a: Component_Type_ID, b: Component_Type_ID) -> bool {
    return a.hash == b.hash;
}

/** Get the type id of a component. Just hash the component type name. */
component_type_id :: ($c: Type) -> Component_Type_ID {
    assert(type_info(c).type == .STRUCT, "Only struct types are supported as component types!");

    ti :: type_info(c);
    is_singleton := has_note(ti, "SingletonComponent");
    hash :: #run fnv1a_hash(ti.name.data, ti.name.count, h = 5381);

    return .{hash, ti.runtime_size, ti.name, ti.initializer, is_singleton};
}

/** Returns a compile-time generated (sorted by id) view of a static array of component type ids */
component_type_ids :: ($component_types: [] Type) -> [] Component_Type_ID {
    #insert #run () -> string #compile_time {
        builder: String_Builder;
        
        print_to_builder(*builder, "result :: Component_Type_ID.[");
        for 0..component_types.count-1 {
            if (cast(*Type_Info) component_types[it]).type == .POINTER {
                print_to_builder(*builder, "#run component_type_id(#run get_type((cast(*Type_Info_Pointer)type_info(component_types[%])).pointer_to)), ", it);
            } else {
                print_to_builder(*builder, "#run component_type_id(component_types[%]), ", it);
            }
        }
        print_to_builder(*builder, "];\n");
        print_to_builder(*builder, "#run quick_sort(result, (x) => x.hash);\n");
        return builder_to_string(*builder);
    }();
    return result;
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
