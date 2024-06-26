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
    stage := ifx entity.deferred then *world.deferred_stage else *world.stage;

    if entity.index >= stage.entities.count then return false;
    if entity.generation != stage.entities[entity.index].generation then return false;
    return true;
}

spawn_entity :: (world: *World, $Initial_Archetype: ..Type) -> Entity {
    #insert -> string {
        sb: String_Builder;
        
        sbprint(*sb, "CTIDS :: Component_Type_ID.[");
        for 0..Initial_Archetype.count-1 {
            sbprint(*sb, "#run component_type_id(Initial_Archetype[%]), ", it);
        }
        sbprint(*sb, "];\n");
        return builder_to_string(*sb);
    };

    return _spawn_entity(world, CTIDS);
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
        return get_component(*world.deferred_stage, entity, #run component_type_id(Component_Type));
    }
    return get_component(*world.stage, entity, #run component_type_id(Component_Type));
}

add_component :: (world: *World, entity: Entity, $Component_Type: Type) -> *Component_Type {
    ctid :: #run component_type_id(Component_Type);

    if entity.deferred {
        return add_component(*world.deferred_stage, entity, ctid);
    }

    if world.should_defer {
        ptr := TempNew(Component_Type);
        array_add(*world.deferred_ops, .{type = .ADD_COMPONENT, entity = entity, type_id = ctid, component_data = ptr});
        return ptr;
    }
    
    result := add_component(*world.stage, entity, ctid);
    // @todo: when to fire the add event if something was deferred?
    broadcast_event(world, ECS_EVENT_ON_ADD);
    return result;
}

add_component :: (world: *World, entity: Entity, $Component_Type: Type, initial_value: Component_Type) -> *Component_Type {
    result := add_component(world, entity, Component_Type);
    << result = initial_value;
    return result;
}

add_components_from_bundle :: (world: *World, entity: Entity, bundle: $T) {
    #assert(type_info(T).type == .STRUCT); // Attempting to add a bundle that is not a struct. Did you accidentally pass a type instead of an instance of the type?

    // @Speed: batch component adds into a single archetype transfer and then copy values over after
    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);

        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "add_component(world, entity, %, bundle.%);\n", member_type_info.name, it.name);
                }
            }
        }

        return builder_to_string(*sb);
    }
}

remove_components_from_bundle :: (world: *World, entity: Entity, $bundle: Type) {
    #assert(type_info(T).type == .STRUCT); // Attempting to use a bundle that is not a struct. Did you accidentally pass a type instead of an instance of the type?

    // @Speed: batch component adds into a single archetype transfer and then copy values over after
    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);

        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "remove_component(world, entity, %);\n", member_type_info.name);
                }
            }
        }

        return builder_to_string(*sb);
    }
}

spawn_from_bundle :: (world: *World, bundle: $T) -> Entity {
    #assert(type_info(T).type == .STRUCT); // Attempting to add a bundle that is not a struct. Did you accidentally pass a type instead of an instance of the type?

    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);

        sbprint(*sb, "Types :: Component_Type_ID.[");
        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "#run component_type_id(%), ", member_type_info.name);
                } else {
                    log_warning("Member (%) of bundle (%) does not have a @Component tag? It will not be added to the entity, was this intentional?", member_type_info.name, ti.name);
                }
            }
        }
        sbprint(*sb, "];");

        return builder_to_string(*sb);
    }

    entity := _spawn_entity(world, Types);

    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);

        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "<< get_component(world, entity, %) = bundle.%;\n", member_type_info.name, it.name);
                }
            }
        }

        return builder_to_string(*sb);
    }

    return entity;
}

remove_component :: (world: *World, entity: Entity, ctid: Component_Type_ID) -> bool {
    if entity.deferred {
        return remove_component(*world.deferred_stage, entity, ctid);
    }

    if world.should_defer {
        array_add(*world.deferred_ops, .{.REMOVE_COMPONENT, entity, ctid, null});
        // @todo: this should return true if the entity actually has the component type
        return true; 
    }
    
    removed := remove_component(*world.stage, entity, ctid);

    // @todo: when to fire the add event if something was deferred?
    broadcast_event(world, ECS_EVENT_ON_REMOVE);
    return removed;
}

remove_component :: (world: *World, entity: Entity, $Component_Type: Type) -> bool {
    return remove_component(world, entity, #run component_type_id(Component_Type));
}

_spawn_entity :: (world: *World, initial_archetype: [] Component_Type_ID) -> Entity {
    // @todo: maybe this can be sorted in the #insert above?
    sorted_ctids: [..] Component_Type_ID;
    sorted_ctids.allocator = temp;
    array_copy(*sorted_ctids, initial_archetype);
    quick_sort(sorted_ctids, (x) => x.hash);

    if world.should_defer {
        entity := add_entity(*world.deferred_stage, sorted_ctids);
        entity.deferred = true;

        array_add(*world.deferred_ops, .{.SPAWN, entity, .{}, null});
        return entity;
    }

    return add_entity(*world.stage, sorted_ctids);
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

    // now try some removing a component that doesn't exist. This should gracefully do nothing and return false
    test_expect_equals(false, remove_component(*world, e1, Test));

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
