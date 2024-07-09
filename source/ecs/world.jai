/**
 * A world is a container of entities and associated component data storage.
 * A game may create multiple worlds, if needed, but there should only be one global game world which represents the main game state.
 */
World :: struct {
    /** The ECS stage where the majority of active game data resides. Queries will only ever iterate over this stage */
    stage: Stage;
    /**
     * The deferred stage is the place where ecs spawns and additions are stored temporarily while we are iterating over queries.
     * This happens to prevent additions from invalidating iterators or pointers to components while within system execution.
     */
    deferred_stage: Stage;

    /**
     * Stores all instances of singleton components.
     */
    singletons: Singleton_Storage;

    /**
     * The list of all deferred ecs operations that have yet to be processed into the main stage.
     */
    deferred_ops: [..] Deferred_ECS_Operation;

    /**
     * Maps a placeholder raw entity id to an entity in the deferred stage.
     */
    deferred_entities: Table(s64, Entity);

    /**
     * Flag that indicates if ecs operations will execute in their deferred mode or active mode.
     * This is always set to true during query iteration.
     */
    should_defer: bool = false;
}

/**
 * Checks if an entity handle is still valid (that entity still exists in the world) by checking the generational index against the current generation in the entities array.
 * @return true if the entity handle is valid for this world.
 */
is_valid :: (world: *World, entity: Entity) -> bool {
    deferred, found := table_find(*world.deferred_entities, entity.raw);
    if found {
        return is_valid(*world.deferred_stage, deferred);
    } else {
        return is_valid(*world.stage, entity);
    }
}

/**
 * Spawns a new entity in the world with a given set of components already attached.
 * The operation may be deferred, if the world is currently iterating over a query set. If this is the case,
 * a consistent entity handle will be returned, and all future calls to add_component/get_component/remove_component will
 * forward to a behind-the-scenes deferred entity handle with the actual component data. Once the query set is resolved, the deferred
 * entity spawn will be processed and fully added to the main scene.
 *
 * Calling `spawn_entity` with component types will broadcast the EcsOnAdd event for each component time immediately when the entity is spawned.
 * 
 * @return Returns a unique entity handle to the newly spawned entity.
 */
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

    return spawn_entity_with_ctids(world, CTIDS);
}

/**
 * Same as `spawn_entity` but takes an array of component type ids instead of a varags list of types.
 * This is useful for initializing an entity with dynamically created ctids, such as in the case of relational components (ex. Child_Of).
 */
spawn_entity_with_ctids :: (world: *World, initial_archetype: [] Component_Type_ID, broadcast := true) -> Entity {
    sorted_ctids: [..] Component_Type_ID;
    sorted_ctids.allocator = temp;
    array_copy(*sorted_ctids, initial_archetype);
    quick_sort(sorted_ctids, (x) => x.unique_id);

    entity: Entity;
    if world.should_defer {
        entity = add_entity(*world.stage, .[]);

        deferred_entity := add_entity(*world.deferred_stage, sorted_ctids);

        array_add(*world.deferred_ops, .{.SPAWN, entity, .{}, null});
        table_add(*world.deferred_entities, entity.raw, deferred_entity);
    } else {
        entity = add_entity(*world.stage, sorted_ctids);
    }

    if broadcast {
        for initial_archetype {
            broadcast_on_component_add(world, entity, it);
        }
    }

    return entity;
}


/**
 * Destroy an entity in the world, causing it's entity handle to not longer be valid.
 * This will also recursively destroy all child entities of the entity to be destroyed.
 * 
 * This operation will be deferred if the world is currently iterating a query set, thereby causing the entity
 * to still appear in queries until the next time the deferred operations are resolved (usually at the end of the current phase of system execution).
 */
destroy_entity :: (world: *World, entity: Entity) {
    assert(is_valid(world, entity));
    if world.should_defer {
        deferred, found := table_find(*world.deferred_entities, entity.raw);
        if found {
            remove_entity(*world.deferred_stage, deferred);
        }
        array_add(*world.deferred_ops, .{type = .DESTROY, entity = entity});

        return;
    }

    // recursively destroy all children:
    children: [..] Entity;
    children.allocator = temp;
    for * iter : make_children_iter(world, entity) {
        for iter.entities {
            array_add(*children, it);
        }
    }
    for children {
        destroy_entity(world, it);
    }

    record, success := table_find(*world.stage.entity_records, entity.raw);
    assert(success);

    for world.stage.archetypes[record.archetype_id].type_ids {
        broadcast_on_component_remove(world, entity, it);
    }

    remove_entity(*world.stage, entity);
}

/** Returns true of a given entity has a component of the given type */
has_component :: (world: *World, entity: Entity, ctid: Component_Type_ID) -> bool {
    return has_components(*world.stage, entity, .[ctid]);
}
has_components :: (world: *World, entity: Entity, ctids: [] Component_Type_ID) -> bool {
    assert(is_valid(world, entity));
    deferred, found := table_find(*world.deferred_entities, entity.raw);
    if found {
        return has_components(*world.deferred_stage, deferred, ctids);
    }

    return has_components(*world.stage, entity, ctids);
}

/** Returns a view to the archetypes type id array */
get_component_types :: (world: *World, entity: Entity) -> [] Component_Type_ID {
    assert(is_valid(world, entity));
    deferred, found := table_find(*world.deferred_entities, entity.raw);
    if found {
        return get_component_types(*world.deferred_stage, deferred);
    }
    return get_component_types(*world.stage, entity);
}

/**
 * Returns a pointer to the component of the given type attached to the given entity.
 */
get_component :: (world: *World, entity: Entity, $Component_Type: Type) -> *Component_Type {
    return get_component(world, entity, #run component_type_id(Component_Type));
}
get_component :: (world: *World, entity: Entity, ctid: Component_Type_ID) -> *void {
    assert(is_valid(world, entity));
    deferred, found := table_find(*world.deferred_entities, entity.raw);
    if found {
        return get_component(*world.deferred_stage, deferred, ctid);
    }
    return get_component(*world.stage, entity, ctid);
}

/**
 * Adds a new component to the given entity of the given type. If the entity already has the component, the function will simply return the existing component.
 * 
 * Component addition is a deferred operation, no queries will see component until the next time queries are resolved.
 * However, the component can still be retrieved via `get_component`.
 *
 * Optionally, an initial value for the component can be passed and it will be immediately initialized before the EcsOnAdd event is broadcast
 */
add_component :: (world: *World, entity: Entity, $Component_Type: Type, initial_value: Component_Type) -> *Component_Type {
    result := add_component(world, entity, Component_Type, broadcast = false);
    << result = initial_value;
    broadcast_on_component_add(world, entity, #run component_type_id(Component_Type));
    return result;
}
add_component :: (world: *World, entity: Entity, $Component_Type: Type, broadcast := true) -> *Component_Type {
    ctid :: #run component_type_id(Component_Type);

    return add_component(world, entity, ctid, broadcast);
}
add_component :: (world: *World, entity: Entity, ctid: Component_Type_ID, broadcast := true) -> *void{
    assert(is_valid(world, entity));
    existing := get_component(world, entity, ctid);
    if existing != null then return existing;

    deferred, found := table_find(*world.deferred_entities, entity.raw);
    if found {
        result := add_component(*world.deferred_stage, deferred, ctid);
        if broadcast broadcast_on_component_add(world, entity, ctid);
        return result;
    }

    if world.should_defer {
        ptr := talloc(ctid.runtime_size);
        array_add(*world.deferred_ops, .{type = .ADD_COMPONENT, entity = entity, type_id = ctid, component_data = ptr});
        if broadcast broadcast_on_component_add(world, entity, ctid);
        return ptr;
    }
    
    result := add_component(*world.stage, entity, ctid);
    if broadcast broadcast_on_component_add(world, entity, ctid);
    return result;
}

/**
 * Adds all component types in a bundle struct to an entity, initializing all the components to the values contained in the bundle struct.
 */
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

/**
 * Removes all component types in a bundle struct from an entity.
 */
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

/**
 * Spawns an entity with all the initial components and corresponding values from a bundle struct.
 */
spawn_entity_from_bundle :: (world: *World, bundle: $T) -> Entity {
    #assert(type_info(T).type == .STRUCT); // Attempting to add a bundle that is not a struct. Did you accidentally pass a type instead of an instance of the type?

    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);
        assert(has_note(ti, "Bundle"), "Attempted to use struct (%) as a bundle but it is not marked as such with a @Bundle note!", ti.name);

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

    entity := spawn_entity_with_ctids(world, Types, broadcast = false);

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

    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);

        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "broadcast_on_component_add(world, entity, #run component_type_id(%));\n", member_type_info.name);
                }
            }
        }

        return builder_to_string(*sb);
    }

    return entity;
}

/**
 * Removes a component type from an entity, returning true if the entity had that component.
 *
 * This is a deferred operation, any component removals will not be visible to queries until the next time deferred operations are resolved.
 * However, immediate calls to `has_component`/`get_component` will return false/null for this type.
 */
remove_component :: (world: *World, entity: Entity, $Component_Type: Type) -> bool {
    return remove_component(world, entity, #run component_type_id(Component_Type));
}
remove_component :: (world: *World, entity: Entity, ctid: Component_Type_ID) -> bool {
    assert(is_valid(world, entity));
    deferred, found := table_find(*world.deferred_entities, entity.raw);
    if found {
        removed := remove_component(*world.deferred_stage, deferred, ctid);
        if removed {
            broadcast_on_component_remove(world, entity, ctid);
        }
    }

    if world.should_defer {
        array_add(*world.deferred_ops, .{.REMOVE_COMPONENT, entity, ctid, null});
        // @todo: this should return true if the entity actually has the component type
        return true; 
    }
    
    removed := remove_component(*world.stage, entity, ctid);

    if removed {
        broadcast_on_component_remove(world, entity, ctid);
    }
    return removed;
}



//------------------------- TESTING -------------------------   

Test :: struct @Component {
    x: u32 = 10;
}
Test2 :: struct @Component {
    x: u32;
}
test_entity_components :: (ctx: *TestContext) {
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

#scope_file


#import "Compiler";
#import "Program_Print";
#import "IntroSort";
