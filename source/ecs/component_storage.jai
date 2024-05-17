/** Stores component data for a single component type in contiguous memory blocks */
ComponentContainer :: struct {
    /** Maps the entity id to the position of it's component in storage */
    indirection: Table(Entity, s64);

    /** List of available slots in the contiguous block of memory */
    free_slots: [..] s64;

    /** Pointer to the start of the component memory */
    data: *void = null;

    /** Current number of allocated components */
    count: s64 = 0;

    /** Maximum number of things we can store before reallocating the data pointer */ 
    size: s64 = 0;

    /** Component data type stored by this container. */
    type: *Type_Info_Struct;
}

/** get the type id of a component. Just hash the component type name. Should ideally only be called at compile time to avoid runtime hashing. */
component_type_id :: ($c: Type) -> s64 {
    assert(type_info(c).type == .STRUCT, "Only struct types are supported as component types!");
    return get_hash(type_info(c).name);
}

add_component :: (cc: *ComponentContainer, entity: Entity, $initialize := true) -> *void {
    assert(!table_contains(*cc.indirection, entity), "Attempted to add a component to an entity that already has one of that type");

    new_index := -1;
    if cc.free_slots.count > 0 {
        new_index = pop(*cc.free_slots);
    } else {
        // if we are at capacity:
        if cc.count == cc.size {
            if cc.data != null {
                // We cannot fit the component in the current size of the container, must reallocate:
                old_alloc_size := cc.size * cc.type.runtime_size;

                // double the previous size when reallocating
                new_data := alloc(2 * old_alloc_size);
                memcpy(new_data, cc.data, old_alloc_size);

                free(cc.data);
                cc.data = new_data;
                cc.size = cc.size * 2;
            } else {
                // cc isn't initialized, allocate our first block with 16 elements worth of storage:
                INITIAL_COMPONENT_COUNT :: 16;
                cc.data = alloc(INITIAL_COMPONENT_COUNT * cc.type.runtime_size);
                cc.count = 0;
                cc.size = INITIAL_COMPONENT_COUNT;
            }
        }
        new_index = cc.count;
        cc.count += 1;
    }

    table_add(*cc.indirection, entity, new_index);

    assert(cc.data != null && cc.count > 0);
    ptr := cc.data + new_index * cc.type.runtime_size;

    #if initialize {
        if cc.type.initializer then cc.type.initializer(ptr);
        else memset(ptr, 0, cc.type.runtime_size);
    }

    assert(ptr != null);

    assert(cc.count == (cc.indirection.count + cc.free_slots.count));

    return ptr;
}

remove_component :: (cc: *ComponentContainer, entity: Entity) -> bool {
    success, removed_index := table_remove(*cc.indirection, entity);

    if !success then return false;

    array_add(*cc.free_slots, removed_index);

    return true;
}

get_component :: (cc: *ComponentContainer, entity: Entity) -> *void {
    index, success := table_find(*cc.indirection, entity);

    if !success then return null;

    return cc.data + index * cc.type.runtime_size;
}

test_component_container :: (ctx: *TestContext) {
    Test :: struct { x: s64; };

    cc: ComponentContainer;
    cc.type = type_info(Test);

    e1: Entity = 1;

    c := cast(*Test) add_component(*cc, e1);
    << c  = .{11};
    c1 := cast(*Test) get_component(*cc, e1);

    test_expect_equals(11, c1.x);

    success := remove_component(*cc, e1);
    test_expect_equals(true, success);
    success = remove_component(*cc, e1);
    test_expect_equals(false, success);

    c = cast(*Test) add_component(*cc, e1);
    << c = .{11};

    e2: Entity = 2;
    e3: Entity = 3;
    c = cast(*Test) add_component(*cc, e2);
    << c = .{12};
    c = cast(*Test) add_component(*cc, e3);
    << c = .{13};
    c2 := cast(*Test) get_component(*cc, e2);
    c3 := cast(*Test) get_component(*cc, e3);

    test_expect_equals(12, c2.x);
    test_expect_equals(13, c3.x);

    remove_component(*cc, e2);
    c1 = cast(*Test) get_component(*cc, e1);
    c3 = cast(*Test) get_component(*cc, e3);
    test_expect_equals(11, c1.x);
    test_expect_equals(13, c3.x);

    e4: Entity = 4;
    c = cast(*Test) add_component(*cc, e4);
    << c = .{14};
    c4 := cast(*Test) get_component(*cc, e4);
    test_expect_equals(14, c4.x);
} @UnitTest

#scope_file

#import "Hash";
#import "Hash_Table";
