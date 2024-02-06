// Gameplay representation of the world
World :: struct {
    /** 
     * Main storage for all common entity data. 
     * Specific per-entity type data is stored in the per-entity-type storage which is generated via metaprogram.
     */
    entities: Bucket_Array(Entity, 64, true);

    /** Locators and EntityIDs that can be reused due to another entity having been removed. */
    reusable_entity_locators: [..] Bucket_Locator;
    reusable_entity_ids: [..] EntityId;

    #insert #run generate_per_entity_type_storage();
}

g_world: World;

make_entity :: (world: *World, $type: Type, name: string = "") -> *type {
    assert(world.reusable_entity_locators.count == world.reusable_entity_ids.count);

    entity := ifx world.reusable_entity_locators.count > 0 {
        locator := pop(*world.reusable_entity_locators);
        entity_id := pop(*world.reusable_entity_ids);
        assert(locator.bucket_index != -1 && locator.slot_index != -1,
            "Somehow an invalid entity locator was added to the list of available entities!");

        entity := *world.entities.all_buckets[locator.bucket_index].data[locator.slot_index];
        entity.id = entity_id;

        entity;
    }
    else {
        locator, entity := bucket_array_add(*world.entities, .{});
        entity.locator = locator;
        entity.id = xx world.entities.count;

        entity;
    };

    entity.entity_type = type;

    #insert #run sprint("_, result := bucket_array_add(*world._%1, .{});", type);
    result.entity = entity;
    entity.data = result;

    result.name = copy_string(name);
    if result.name.count == 0 {
        result.name = sprint("%_%", type, entity.id);
    }

    return result;
}

destroy_entity :: (world: *World, entity: *$T) {
    array_add(*world.reusable_entity_locators, entity.locator);
    array_add(*world.reusable_entity_ids, entity.id);
    entity.id =  INVALID_EID;

    #insert #run sprint("for * world._%1 { if it.id == entity.id then remove it; };", T);
}

#scope_file

generate_per_entity_type_storage :: () -> string {
    w := get_current_workspace();
    table := get_type_table(w);

    entity_type_names: [..] string;

    for table {
        if it.type != .STRUCT continue;

        info_struct := cast(*Type_Info_Struct) it;

        if is_subclass_of(it, "Entity") {
            array_add(*entity_type_names, info_struct.name);
        }
    }
    builder: String_Builder;
    defer free_buffers(*builder);

    ITEMS_PER_BUCKET :: 64;

    for entity_type_names {
        print_to_builder(*builder, "    _%1: Bucket_Array(%1, %2, true);\n", it, ITEMS_PER_BUCKET);
    }

    return builder_to_string(*builder);
}

#scope_export

generate_code :: () {
    // Browse through the type table to look for subclasses of Entity.
    // Since the metaprogram only calls this routine
    // when everything is typechecked, and no additional entities are added
    // during subsequent waves of code generation (and no entities depend
    // on code that is generated for any of their members to be defined),
    // we know everything is ready by the time we are called.

    w := get_current_workspace();
    table := get_type_table(w);

    entity_type_names: [..] string;

    for table {
        if it.type != .STRUCT continue;

        info_struct := cast(*Type_Info_Struct) it;

        if is_subclass_of(it, "Entity") {
            array_add(*entity_type_names, info_struct.name);
        }
    }

    quick_sort(entity_type_names, compare_strings);

    type_names := join(..entity_type_names, ", ");

    entity_iterator_string: string;
    {
        iterator_builder: String_Builder;

        for entity_type_names {
            print_to_builder(*iterator_builder, ENTITY_TYPE_ITERATOR, it);
        }

        entity_iterator_string = builder_to_string(*iterator_builder);
    }

    build_string := sprint(INSERTION_STRING, entity_iterator_string);

    add_build_string(build_string, w = -1);

} @RunWhenReady


#scope_file

INSERTION_STRING :: #string DONE
%1
DONE

ENTITY_TYPE_ITERATOR :: #string DONE
%1_It :: (world: *World, body: Code, flags: For_Flags) #expand {
    // body was copied from bucket_array's for expansion
    array := *world._%1;
    `it_index: int;

    REVERSE :: cast(bool) (flags & .REVERSE);
    
    #if REVERSE it_index = array.count;
    else        it_index = -1;
    
    DO_POINTER :: (flags & .POINTER) || array.always_iterate_by_pointer;
    
    for <=REVERSE bucket, bi: array.all_buckets {
        for <=REVERSE *=DO_POINTER  `it, i: bucket.data {
            if !bucket.occupied[i] continue;

            #if REVERSE  it_index -= 1;
            else         it_index += 1;

            #insert (break=break bucket, 
                    remove={
                        locator: Bucket_Locator; 
                        locator.bucket_index = cast(u32) bi; 
                        locator.slot_index = cast(s32) i; 
                        bucket_array_remove(array, locator); 
                        destroy_entity(world, it);
                    }) 
                    body;
        }
    }
}
DONE

#import "Compiler";
#import "Sort";
#import "Basic";
#import "String";
#import "Bucket_Array";