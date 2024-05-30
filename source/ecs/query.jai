Query :: struct ($component_types: ..Type) {
    #insert #run generate_query_members(..component_types);

    world: *World;
    entities: [] Entity;

    count: s64;
}

/** Returns a compile-time generated (sorted by id) view of a static array of component type ids for this query */
get_component_types_for_query :: (query: Query) -> [] Component_Type_ID {
    #insert #run () -> string {
        builder: String_Builder;
        
        print_to_builder(*builder, "result :: Component_Type_ID.[");
        for 0..query.component_types.count-1 {
            if (cast(*Type_Info) query.component_types[it]).type == .POINTER {
                print_to_builder(*builder, "#run component_type_id(#run get_type((cast(*Type_Info_Pointer)type_info(query.component_types[%])).pointer_to)), ", it);
            } else {
                print_to_builder(*builder, "#run component_type_id(query.component_types[%]), ", it);
            }
        }
        print_to_builder(*builder, "];\n");
        print_to_builder(*builder, "#run quick_sort(result, (x) => x.hash);\n");
        return builder_to_string(*builder);
    }();
    return result;
}

for_expansion :: (query: Query, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.
    #assert(!(flags & .POINTER)); // we don't handle the pointer flag either.

    assert(query.world != null);

    types := get_component_types_for_query(query);

    for * archetype, archetype_id : query.world.archetypes {
        if !archetype_contains_types(archetype, types) then continue;

        query.count = archetype.entities.count;
        query.entities = archetype.entities;

        #insert -> string {
            builder: String_Builder;
            defer free_buffers(*builder);

            for 0..query.component_types.count-1 {
                ti: *Type_Info_Struct = null;

                if (cast(*Type_Info) query.component_types[it]).type == .POINTER {
                    ti = cast(*Type_Info_Struct) (cast(*Type_Info_Pointer) query.component_types[it]).pointer_to;
                    print_to_builder(
                        *builder, 
                        "query.%1.data = xx get_iter(archetype, #run component_type_id(#run get_type((cast(*Type_Info_Pointer)query.component_types[%2]).pointer_to)));\nquery.%1.count = query.count;\n",
                        to_lower_copy_new(ti.name),
                        it);
                } else {
                    ti = cast(*Type_Info_Struct) query.component_types[it];
                    print_to_builder(
                        *builder,
                        "query.%.data = xx get_iter(archetype, #run component_type_id(query.component_types[%]));\nquery.%1.count = query.count;\n",
                        to_lower_copy_new(ti.name),
                        it);
                }
            }
            return builder_to_string(*builder);
        }

        `it := query;
        `it_index := archetype_id;

        #insert body;
    }
}


#scope_file

DISABLE_QUERY_CACHE :: false;

generate_query_members :: ($component_types: ..Type) -> string #compile_time {
    builder: String_Builder;
    defer free_buffers(*builder);
    for 0..component_types.count-1 {
        ti: *Type_Info_Struct = null;
        if (cast(*Type_Info) component_types[it]).type == .POINTER {
            ti = cast(*Type_Info_Struct) (cast(*Type_Info_Pointer) component_types[it]).pointer_to;
            //print_to_builder(*builder, "#run component_type_id(#run get_type((cast(*Type_Info_Pointer)type_info(query.component_types[%])).pointer_to)), ", it);
            print_to_builder(*builder, "%: [] #run get_type((cast(*Type_Info_Pointer) component_types[%]).pointer_to);\n", to_lower_copy_new(ti.name), it);
        } else {
            ti = cast(*Type_Info_Struct) component_types[it];
            print_to_builder(*builder, "%: [] component_types[%];\n", to_lower_copy_new(ti.name), it);
        }
    }
    return builder_to_string(*builder);
}

#scope_export

test_ecs_query :: (ctx: *TestContext) {
    Test :: struct {
        x: u32;
    }

    Test2 :: struct {
        x: u32;
    }

    world: World;

    e1 := spawn_entity(*world);
    c1 := add_component(*world, e1, Test);
    c1.x = 11;
    c2 := add_component(*world, e1, Test2);
    c2.x = 12;

    e2 := spawn_entity(*world);
    add_component(*world, e2, Test);

    num_iters := 0;
    for query : Query(*Test, *Test2).{world = *world} {
        test_assert_not_equals(null, query.test.data);
        test_assert_not_equals(null, query.test2.data);

        for 0..query.count-1 {
            entity := it_index;

            test_expect_equals(11, query.test[it].x);
            test_expect_equals(12, query.test2[it].x);

            num_iters += 1;
        }
    }

    test_expect_equals(1, num_iters);
} @UnitTest

#import "Bit_Operations";
