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
    unique_id: u64;
    debug_name: string;

    runtime_size: s64;
    initializer: (*void);
    is_singleton: bool;
}

operator== :: (a: Component_Type_ID, b: Component_Type_ID) -> bool {
    return compare_ctid(a, b);
}

compare_ctid :: (a: Component_Type_ID, b: Component_Type_ID) -> bool {
    return a.unique_id == b.unique_id;
}

compare_ctids :: (a: [] Component_Type_ID, b: [] Component_Type_ID) -> bool {
    if a.count != b.count then return false;
    // component type arrays are always sorted, so we can simply check each element with it's pair
    for 0..a.count-1 {
        if a[it] != b[it] then return false;
    }
    return true;
}

NULL_COMPONENT_ID : u64 : 0;

component_type_id :: inline ($c: Type) -> Component_Type_ID 
{
    assert(type_info(c).type == .STRUCT, "Only struct types are supported as component types!");

    ti :: type_info(c);
    is_singleton :: #run has_note(ti, "SingletonComponent");

    UNIQUE_ID :: #run -> u64 {
        found, index := array_find(ALL_COMPONENT_TYPES, c);
        assert(found, "Component type not found: %", ti.name);
        return cast(u64) index + 1;
    }

    assert(UNIQUE_ID != NULL_COMPONENT_ID);

    return Component_Type_ID.{
        unique_id = UNIQUE_ID,
        runtime_size = ti.runtime_size,
        debug_name = ti.name,
        initializer = ti.initializer,
        is_singleton = is_singleton
    };
}

#insert -> string {
    sb: String_Builder;
    sbprint(*sb, "ALL_COMPONENT_TYPE_IDS :: Component_Type_ID.[");
    for ALL_COMPONENT_TYPES {
        ti := cast(*Type_Info_Struct)it;
        sbprint(*sb, "#run component_type_id(%), ", ti.name);
    }
    sbprint(*sb, "];");

    return builder_to_string(*sb);
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
        print_to_builder(*builder, "#run quick_sort(result, (x) => x.unique_id);\n");
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
#import "Atomics";