/**
 * A world is a container of entities and associated component data storage.
 * A game may create multiple worlds, if needed, but there should only be one global game world which represents the main game state.
 */
World :: struct {
    stage: Stage;
    deferred_stage: Stage;

    singletons: Singleton_Storage;

    deferred_ops: [..] Deferred_ECS_Operation;

    should_defer: bool = false;
}

Entity_Record :: struct {
    archetype_id: s64;
    row: s64;
}

is_entity_valid :: (world: *World, entity: Entity) -> bool {
    if entity.index == INVALID_ENTITY_INDEX then return false;
    if entity.index >= world.stage.entities.count then return false;
    if entity.generation != world.stage.entities[entity.index].generation then return false;
    return true;
}

spawn_entity :: (world: *World, $Initial_Archetype: ..Type) -> Entity {
    #insert #run () -> string {
        sb: String_Builder;
        
        sbprint(*sb, "CTIDS :: Component_Type_ID.[");
        for 0..Initial_Archetype.count-1 {
            sbprint(*sb, "#run component_type_id(Initial_Archetype[%]), ", it);
        }
        sbprint(*sb, "];\n");
        sbprint(*sb, "#run intro_sort(CTIDS, (a, b) => cast, trunc(int)a.hash - cast, trunc(int) b.hash);\n");
        return builder_to_string(*sb);
    }();

    if world.should_defer {
        entity := add_entity(*world.deferred_stage, CTIDS);
        entity.deferred = true;
        return entity;
    }

    return add_entity(*world.stage, CTIDS);
}

destroy_entity :: (world: *World, entity: Entity) {
    if world.should_defer {
        if entity.deferred {
            remove_entity(*world.deferred_stage, entity);
        } else {
            array_add(*world.deferred_ops, .{type = .DESTROY, entity = entity});
        }

        return;
    }

    remove_entity(*world.stage, entity);
}

get_component :: (world: *World, entity: Entity, $Component_Type: Type) -> *Component_Type {
    if entity.deferred {
        return get_component(*world.deferred_stage, entity, Component_Type);
    }
    return get_component(*world.stage, entity, Component_Type);
}

add_component :: (world: *World, entity: Entity, $Component_Type: Type) -> *Component_Type {
    if entity.deferred {
        return add_component(*world.deferred_stage, entity, Component_Type);
    }
    
    result := add_component(*world.stage, entity, Component_Type);
    // @todo: when to fire the add event if something was deferred?
    broadcast_event(world, ECS_EVENT_ON_ADD);
    return result;
}

add_component :: (world: *World, entity: Entity, $Component_Type: Type, initial_value: Component_Type) -> *Component_Type {
    result := add_component(world, entity, Component_Type);
    << result = initial_value;
    return result;
}

remove_component :: (world: *World, entity: Entity, $Component_Type: Type) {
    if entity.deferred {
        remove_component(*world.deferred_stage, entity, Component_Type);
        return;
    }
    
    remove_component(*world.stage, entity, Component_Type);

    // @todo: when to fire the add event if something was deferred?
    broadcast_event(world, ECS_EVENT_ON_REMOVE);
}

compare_ctids :: (a: [] Component_Type_ID, b: [] Component_Type_ID) -> bool {
    if a.count != b.count then return false;
    // component type arrays are always sorted, so we can simply check each element with it's pair
    for 0..a.count-1 {
        if a[it] != b[it] then return false;
    }
    return true;
}

//------------------------- TESTING -------------------------   


test_entity_components :: (ctx: *TestContext) {
    Test :: struct {
        x: u32 = 10;
    }
    Test2 :: struct {
        x: u32;
    }
    world: World;

    e1 := spawn_entity(*world);
    test_expect_not_equals(INVALID_ENTITY_INDEX, e1.index);
    test_expect_equals(0, e1.generation);
    e2 := spawn_entity(*world);
    e3 := spawn_entity(*world);

    // try adding a component
    c1 := add_component(*world, e1, Test);
    // make sure that accessing the component returns the same pointer that we got when adding
    test_expect_equals(c1, get_component(*world, e1, Test));
    // make sure the default value is correct
    test_expect_equals(c1.x, 10);

    // do this again a few more times
    c2 := add_component(*world, e2, Test);
    test_expect_equals(c2, get_component(*world, e2, Test));
    c3 := add_component(*world, e3, Test);
    test_expect_equals(c3, get_component(*world, e3, Test));


    remove_component(*world, e1, Test);

    test_expect_equals(null, get_component(*world, e1, Test));

    // now try some removing a component that doesn't exist. This should gracefully do nothing
    remove_component(*world, e1, Test);

    e4 := spawn_entity(*world, Test);
    test_expect_not_equals(null, get_component(*world, e4, Test));
    test_expect_equals(get_component(*world, e4, Test).x, 10);
    get_component(*world, e4, Test).x = 11;

    // add a new component to e4, this will trigger an archetype change:
    add_component(*world, e4, Test2);
    // ensure the old component is still present and has the expected value
    test_expect_not_equals(null, get_component(*world, e4, Test));
    test_expect_equals(get_component(*world, e4, Test).x, 11);

    test_expect_not_equals(null, get_component(*world, e4, Test2));
    // make sure the default value is correct:
    test_expect_equals(get_component(*world, e4, Test2).x, 0);

    destroy_entity(*world, e4);
    e5 := spawn_entity(*world);
    test_expect_equals(e4.index, e5.index);
    test_expect_not_equals(e4.generation, e5.generation);
} @UnitTest

#load "component_storage.jai";
#load "entity.jai";
#load "query.jai";
#load "archetype.jai";
#load "event.jai";
#load "defer.jai";
#load "stage.jai";

#scope_file


#import "Compiler";
#import "Program_Print";
#import "IntroSort";
