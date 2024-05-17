/**
 * A world is a container of entities and associated component data storage.
 * A game may create multiple worlds, if needed, but there should only be one global game world which represents the main game state.
 */
World :: struct {
    /** A list of all currently alive entities */
    entities: [..] Entity;

    free_entity_indices: [..] s32;

    /** Storage for all component types. */
    components: Table(s64, ComponentContainer);

    /** Cached results of queries over component types. Significantly accelerates entity iteration for systems. */
    cached_queries: Table([..] s64, Query_Cache, given_compare_function=compare_query_types);

    /** Debug flag that is set when systems are iterating over the entities. We use this to track if the user tried to add or remove entities while iterating */
    currently_iterating: bool;
}


/**
 * Spawn a new entity in ther world. Optionally, you can provide a list of types that this entity should have when it spawns.
 *
 * IMPORTANT: This function should never be called while systems are iterating over queries!
 * 
 * Example:
 * new_entity := spawn_entity(world); // Creates a new entity with no components attached
 *
 * Example 2: 
 * new_entity := spawn_entity(world, Position, Velocity); // Creates a new entity with a default initialized Position and Velocity component
 */
spawn_entity :: (world: *World, $initial_component_types: ..Type) -> Entity {
    assert(!world.currently_iterating, "Spawning an entity while iterating in a Query is not permitted!");

    if world.free_entity_indices.count > 0 {
        index := pop(*world.free_entity_indices);
        world.entities[index].generation += 1;
        world.entities[index].index = index;

        return .{index = index, generation = world.entities[index].generation};
    }

    new_entity := array_add(*world.entities);
    new_entity.generation = 0;
    new_entity.index = cast(s32) world.entities.count-1;

    #insert #run () -> string {
        builder: String_Builder;

        for 0..initial_component_types.count-1 {
            print_to_builder(*builder, "add_component(world, new_entity, initial_component_types[%]);\n", it);
        }

        return builder_to_string(*builder);
    }();

    return new_entity;
}

/**
 * Destroy and entity in the world.
 *
 * IMPORTANT: This function should never be called while systems are iterating over queries!
 */
destroy_entity :: (world: *World, entity: Entity) {
    assert(!world.currently_iterating, "Destroying an entity while iterating in a Query is not permitted!");

    // #todo [roey]: we should be able to accelerate this by storing bitset for each entity to determine what components it has
    for * world.components {
        key, value := it_index, it;
        remove_component(value, entity);
    }

    invalidate_caches_for_entity(world, entity);

    array_add(*world.free_entity_indices, entity.index);
    world.entities[entity.index].index = INVALID_ENTITY_INDEX;
}

/**
 * Attach a new instance of $component type to the entity.
 *
 * Example:
 * new_entity := spawn_entity(world);
 * position := add_component(world, new_entity, Position); // adds a new Position component to the entity and returns a pointer to it
 *
 * Example 2:
 * position := add_component(world, new_entity, Position, .{10, 10}); // adds a new Position component and gives it the initial value of {10, 10}
 */

add_component :: (world: *World, entity: Entity, $component: Type, $initialize := true) -> *component {
    assert(is_entity_valid(world, entity));

    type_id :: #run component_type_id(component);

    cc := table_find_pointer(*world.components, type_id);
    if cc == null {
        cc = table_add(*world.components, type_id, .{type = type_info(component)});
    }

    invalidate_caches_for_type(world, type_id);

    return cast(*component) add_component(cc, entity, initialize);
}
/** Same as the other add_component but you can provide an optional default value */
add_component :: (world: *World, entity: Entity, $component: Type, val: component) -> *component {
    ptr := add_component(world, entity, component, false);
    << ptr = val;
    return ptr;
}

/**
 * Removes the component of the passed type from the entity, if it had that component. 
 *
 * Example:
 * remove_component(world, my_entity, Position); // Removes the Position component from my_entity, if it had it.
 */
remove_component :: (world: *World, entity: Entity, $component: Type) -> bool {
    assert(is_entity_valid(world, entity));

    type_id :: #run component_type_id(component);

    cc := table_find_pointer(*world.components, type_id);

    invalidate_caches_for_type(world, type_id);

    if cc != null {
        return remove_component(cc, entity);
    }
    return false;
}

/**
 * Retrieves the component of a specified type for a given entity, if it has one. Returns a pointer to the component or null if the entity does not have the component.
 *
 * Example:
 * position := get_component(world, my_entity, Position);
 */
get_component :: (world: *World, entity: Entity, $component: Type) -> *component {
    assert(is_entity_valid(world, entity));

    cc := table_find_pointer(*world.components, #run component_type_id(component));

    if cc == null then return null;

    return cast(*component) get_component(cc, entity);
}

is_entity_valid :: (world: *World, entity: Entity) -> bool {
    if entity.index == INVALID_ENTITY_INDEX then return false;
    if entity.index >= world.entities.count then return false;
    if entity.generation != world.entities[entity.index].generation then return false;
    return true;
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
    test_expect_not_equals(INVALID_ENTITY_INDEX, e1.index);
    test_expect_equals(0, e1.generation);
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

    destroy_entity(*world, e4);
    e5 := spawn_entity(*world);
    test_expect_equals(e4.index, e5.index);
    test_expect_not_equals(e4.generation, e5.generation);
} @UnitTest

#load "component_storage.jai";
#load "entity.jai";
#load "query.jai";

#scope_file

compare_query_types :: (a: [..] s64, b: [..] s64) -> bool {
    if a.count != b.count then return false;
    for a_val : a {
        found, index := array_find(b, a_val);
        if !found then return false;
    }
    return true;
}

invalidate_caches_for_type :: (world: *World, type: s64) {
    for * world.cached_queries {
        key, value := it_index, it;
        found := array_find(key, type);
        if found then value.dirty = true;
    }
}

invalidate_caches_for_entity :: (world: *World, entity: Entity) {
    for * world.cached_queries {
        key, value := it_index, it;
        found := array_find(value.cached_entities, entity);
        if found then value.dirty = true;
    }
}

#import "Compiler";
#import "Program_Print";
#import "Hash_Table";
