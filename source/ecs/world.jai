World :: struct {
    entities: [..] Entity;
    components: Table(s64, ComponentContainer);
}

spawn_entity :: (world: *World, $initial_component_types: ..Type) -> Entity {
    entity: Entity = next_entity_id;
    next_entity_id += 1;

    array_add(*world.entities, entity);

    #insert #run () -> string {
        builder: String_Builder;

        for 0..initial_component_types.count-1 {
            print_to_builder(*builder, "add_component(world, entity, initial_component_types[%]);\n", it);
        }

        return builder_to_string(*builder);
    }();

    return entity;
}

destroy_entity :: (world:* World, entity: Entity) -> bool {
    // #todo [roey]: we should be able to accelerate this by storing bitset for each entity to determine what components it has
    for * world.components {
        key, value := it_index, it;
        remove_component(value, entity);
    }

    return array_ordered_remove_by_value(*world.entities, entity);
}

add_component :: (world: *World, entity: Entity, $component: Type, val: component) -> *component {
    ptr := add_component(world, entity, component);
    << ptr = val;
    return ptr;
}

add_component :: (world: *World, entity: Entity, $component: Type) -> *component {
    cc := table_find_pointer(*world.components, #run component_type_id(component));
    if cc == null {
        cc = table_add(*world.components, #run component_type_id(component), .{type = type_info(component)});
    }

    return cast(*component) add_component(cc, entity);
}

remove_component :: (world: *World, entity: Entity, $component: Type) {
    cc := table_find_pointer(*world.components, #run component_type_id(component));

    if cc != null {
        remove_component(cc, entity);
    }
}

get_component :: (world: *World, entity: Entity, $component: Type) -> *component {
    cc := table_find_pointer(*world.components, #run component_type_id(component));

    if cc == null then return null;

    return cast(*component) get_component(cc, entity);
}


test_entity_components :: (ctx: *TestContext) {
    Test :: struct {
        x: u32;
    }
    Test2 :: struct {
        x: u32;
    }
    world: World;

    e1 := spawn_entity(*world);
    test_expect_not_equals(INVALID_EID, e1);
    e2 := spawn_entity(*world);
    e3 := spawn_entity(*world);

    // try adding a component
    c1 := add_component(*world, e1, Test);
    // make sure that accessing the component returns the same pointer that we got when adding
    test_expect_equals(c1, get_component(*world, e1, Test));

    // do this again a few more times
    c2 := add_component(*world, e2, Test);
    test_expect_equals(c2, get_component(*world, e2, Test));
    c3 := add_component(*world, e3, Test);
    test_expect_equals(c3, get_component(*world, e3, Test));


    remove_component(*world, e1, Test);

    test_expect_equals(null, get_component(*world, e1, Test));

    // now try some removing a component that doesn't exist. This should gracefully do nothing
    remove_component(*world, e1, Test);

    e4 := spawn_entity(*world, Test, Test2);
    test_expect_not_equals(null, get_component(*world, e4, Test));
    test_expect_not_equals(null, get_component(*world, e4, Test2));
} @UnitTest

#load "component_storage.jai";
#load "entity.jai";

#scope_file

#import "Compiler";
#import "Program_Print";
#import "Hash_Table";
