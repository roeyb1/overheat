/**
 * A world is a container of entities and associated component data storage.
 * A game may create multiple worlds, if needed, but there should only be one global game world which represents the main game state.
 */
World :: struct {
    /** A list of all currently alive entities */
    entities: [..] Entity;
    free_entity_indices: [..] s32;

    /** Maps an entity to it's archetype index */
    entity_records: Table(s64, Entity_Record);

    archetypes: [..] Archetype;
}

Entity_Record :: struct {
    archetype_id: s64;
    row: s64;
}

is_entity_valid :: (world: *World, entity: Entity) -> bool {
    if entity.index == INVALID_ENTITY_INDEX then return false;
    if entity.index >= world.entities.count then return false;
    if entity.generation != world.entities[entity.index].generation then return false;
    return true;
}

spawn_entity :: (world: *World, $Initial_Archetype: ..Type) -> Entity {
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
        
        print_to_builder(*builder, "CTIDS :: Component_Type_ID.[");
        for 0..Initial_Archetype.count-1 {
            print_to_builder(*builder, "#run component_type_id(Initial_Archetype[%]), ", it);
        }
        print_to_builder(*builder, "];\n");
        print_to_builder(*builder, "#run quick_sort(CTIDS, (x) => x.hash);\n");
        return builder_to_string(*builder);
    }();

    archetype, archetype_id := get_or_create_archetype(world, CTIDS);
    row := add_entity(archetype);

    table_add(*world.entity_records, new_entity.raw, .{archetype_id = archetype_id, row = row});

    return new_entity;
}

destroy_entity :: (world: *World, entity: Entity) {
    old_record, success := table_find(*world.entity_records, entity.raw);
    if !success then return;

    swapped_row := remove_entity(*world.archetypes[old_record.archetype_id], old_record.row);

    // the record for the element that got swapped into the removed entities place needs to be updated to reflect the new row:
    if swapped_row >= 0 {
        for * world.entity_records {
            record := it;
            if record.row == swapped_row {
                record.row = old_record.row;
                break;
            }
        }
    }

    array_add(*world.free_entity_indices, entity.index);
}

get_component :: (world: *World, entity: Entity, $Component_Type: Type) -> *Component_Type {
    record, success := table_find(*world.entity_records, entity.raw);
    if !success then return null;

    return get_component(*world.archetypes[record.archetype_id], record.row, component_type_id(Component_Type));
}

add_component :: (world: *World, entity: Entity, $Component_Type: Type, $initialize := true) -> *Component_Type {
    record := table_find_pointer(*world.entity_records, entity.raw);
    assert(record != null);
    if record == null then return null;

    new_ctid := component_type_id(Component_Type);

    from := *world.archetypes[record.archetype_id];
    to, to_id := archetype_plus(world, from.type_ids, new_ctid);

    new_row := move_entity(to, from, record.row);

    record.row = new_row;
    record.archetype_id = to_id;

    result := get_component(to, record.row, new_ctid);
    
    #if initialize {
        if type_info(Component_Type).initializer then type_info(Component_Type).initializer(result);
        else memset(result, 0, type_info(Component_Type).runtime_size);
    }
    
    return result;
}

add_component :: (world: *World, entity: Entity, $Component_Type: Type, initial_value: Component_Type) -> *Component_Type {
    result := add_component(world, entity, Component_Type, initialize = false);
    << result = initial_value;
    return result;
}

remove_component :: (world: *World, entity: Entity, $Component_Type: Type) {
    record := table_find_pointer(*world.entity_records, entity.raw);
    assert(record != null);
    if record == null then return;

    new_ctid := component_type_id(Component_Type);

    from := *world.archetypes[record.archetype_id];
    to, to_id := archetype_minus(world, from.type_ids, new_ctid);

    new_row := move_entity(to, from, record.row);

    record.row = new_row;
    record.archetype_id = to_id;
}

#scope_file

archetype_plus :: (world: *World, ctids: [] Component_Type_ID, plus: Component_Type_ID) -> (*Archetype, s64) {
    new_types: [..] Component_Type_ID;
    new_types.allocator = temp;
    array_copy(*new_types, ctids);
    array_add(*new_types, plus);
    quick_sort(new_types, (x) => x.hash);

    archetype, id := get_or_create_archetype(world, new_types);
    return archetype, id;
}

archetype_minus :: (world: *World, ctids: [] Component_Type_ID, minus: Component_Type_ID) -> (*Archetype, s64) {
    new_types: [..] Component_Type_ID;
    new_types.allocator = temp;
    array_copy(*new_types, ctids);

    // ordered remove by value
    {
        for new_types if it == minus { array_ordered_remove_by_index(*new_types, it_index); break; };
    }

    archetype, id := get_or_create_archetype(world, new_types);
    return archetype, id;
}

get_or_create_archetype :: (world: *World, ctids: [] Component_Type_ID) -> (*Archetype, s64) {
    for * world.archetypes {
        if archetype_matches_types(it, ctids) {
            return it, it_index;
        }
    }

    result := array_add(*world.archetypes);
    init(result, ctids);

    return result, world.archetypes.count-1;
}


//------------------------- TESTING -------------------------   

#scope_export

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
#load "archetype.jai";

#scope_file


#import "Compiler";
#import "Program_Print";
