ComponentContainerBase :: struct {
    indirection: Table(Entity, s64);
    type: Type;
}

ComponentContainer :: struct(T: Type){
    #as using base: ComponentContainerBase;
    base.type = T;

    data: [..] T;
}

/** get the type id of a component. Just hash the component type name. Should ideally only be called at compile time to avoid runtime hashing. */
component_type_id :: ($c: Type) -> s64 {
    return get_hash(type_info(c).name);
}

add_component :: (cc: *ComponentContainer, entity: Entity, val: cc.T = cc.T.{}) -> *cc.T {
    assert(!table_contains(*cc.indirection, entity));

    new_index := cc.data.count;
    table_add(*cc.indirection, entity, new_index);
    ptr := array_add(*cc.data);

    assert(cc.indirection.count == cc.data.count);

    << ptr = val;

    return ptr;
}

remove_component :: (cc: *ComponentContainer, entity: Entity) -> bool {
    success, index_to_remove := table_remove(*cc.indirection, entity);

    if !success then return false;

    last_index := cc.data.count - 1;

    last_data := pop(*cc.data);
    // swap the last element into the position of the removed element if there is more than one component.
    // if there's only one component, last_data is the data to remove so we're good.
    if cc.data.count > 0 {
        cc.data[index_to_remove] = last_data;

        for *cc.indirection {
            key, value := it_index, it;
            if (<< value) == last_index {
                << value = index_to_remove;
                break;
            }
        }
    }

    assert(cc.indirection.count == cc.data.count);

    return true;
}

get_component :: (cc: *ComponentContainer, entity: Entity) -> *cc.T {
    index, success := table_find(*cc.indirection, entity);

    if !success then return null;

    return cc.data.data + index;
}

test_component_container :: (ctx: *TestContext) {
    Test :: struct { x: s64; };

    cc: ComponentContainer(Test);

    e1: Entity = 1;

    add_component(*cc, e1, .{11});
    c1 := get_component(*cc, e1);

    test_expect_equals(11, c1.x);

    success := remove_component(*cc, e1);
    test_expect_equals(true, success);
    success = remove_component(*cc, e1);
    test_expect_equals(false, success);

    add_component(*cc, e1, .{11});

    e2: Entity = 2;
    e3: Entity = 3;
    add_component(*cc, e2, .{12});
    add_component(*cc, e3, .{13});
    c2 := get_component(*cc, e2);
    c3 := get_component(*cc, e3);

    test_expect_equals(12, c2.x);
    test_expect_equals(13, c3.x);

    remove_component(*cc, e2);
    c1 = get_component(*cc, e1);
    c3 = get_component(*cc, e3);
    test_expect_equals(11, c1.x);
    test_expect_equals(13, c3.x);

    e4: Entity = 4;
    add_component(*cc, e4, .{14});
    c4 := get_component(*cc, e4);
    test_expect_equals(14, c4.x);
} @UnitTest

#scope_file

#import "Hash";