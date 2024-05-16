Query :: struct ($component_types: ..Type) {
    #insert #run generate_query_members(..component_types);

    world: *World;
}

generate_query_members :: ($component_types: ..Type) -> string #compile_time {
    builder: String_Builder;
    defer free_buffers(*builder);
    for 0..component_types.count-1 {
        ti: *Type_Info_Struct = null;
        if (cast(*Type_Info) component_types[it]).type == .POINTER {
            ti = cast(*Type_Info_Struct) (cast(*Type_Info_Pointer) component_types[it]).pointer_to;
        } else {
            ti = cast(*Type_Info_Struct) component_types[it];
        }
        print_to_builder(*builder, "%: component_types[%];\n", to_lower_copy_new(ti.name), it);
    }
    return builder_to_string(*builder);
}

for_expansion :: (query: Query, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.
    #assert(!(flags & .POINTER)); // we don't handle the pointer flag either.

    assert(query.world != null);

    removed_entities: [..] Entity;
    removed_entities.allocator = temp;

    for entity : query.world.entities {
        #insert #run () -> string {
            builder: String_Builder;
            
            print_to_builder(*builder, "matches_query := true");
            for 0..query.component_types.count-1 {
                if (cast(*Type_Info) query.component_types[it]).type == .POINTER {
                    print_to_builder(*builder, " && get_component(query.world, entity, #run get_type((cast(*Type_Info_Pointer)type_info(query.component_types[%])).pointer_to))", it);
                } else {
                    print_to_builder(*builder, " && get_component(query.world, entity, query.component_types[%])", it);
                }
            }
            print_to_builder(*builder, ";\n");
            return builder_to_string(*builder);
        }();
        
        if !matches_query {
            continue;
        }

        #insert #run () -> string {
            builder: String_Builder;
            defer free_buffers(*builder);

            types: [query.component_types.count] Type;

            for 0..query.component_types.count-1 {
                ti: *Type_Info_Struct = null;

                if (cast(*Type_Info) query.component_types[it]).type == .POINTER {
                    ti = cast(*Type_Info_Struct) (cast(*Type_Info_Pointer) query.component_types[it]).pointer_to;
                    print_to_builder(*builder, "query.% = get_component(query.world, entity, #run get_type((cast(*Type_Info_Pointer)query.component_types[%]).pointer_to));\n", to_lower_copy_new(ti.name), it);
                } else {
                    ti = cast(*Type_Info_Struct) query.component_types[it];
                    print_to_builder(*builder, "query.% = get_component(query.world, entity, query.component_types[%]);\n", to_lower_copy_new(ti.name), it);
                }
            }
            return builder_to_string(*builder);
        }();

        `it := query;
        `it_index := entity;

        // Additional validation for debug builds:
        // Store a copy of the query struct before the body of the loop executes so we can check if the user modified any structs.
        // This can catch potential bugs where the user meant to make a query by-reference but forgot to add the pointer.
        #if DEBUG {
            query_before := it;
        }
        #insert (remove={ array_add(*removed_entities, entity); }) body;
        #if DEBUG {
            assert(bits_equal(*query_before, *it), "Query was modified during system execution! This is probably a bug due to a missing by-reference component. Before %, after %", query_before, it);
        }
    }
    for removed_entities {
        destroy_entity(query.world, it);
    }
}


#scope_file

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
    for Query(*Test, *Test2).{world = *world} {
        entity := it_index;

        test_assert_not_equals(null, it.test);
        test_expect_equals(11, it.test.x);
        test_assert_not_equals(null, it.test2);
        test_expect_equals(12, it.test2.x);

        num_iters += 1;
    }

    test_expect_equals(1, num_iters);
} @UnitTest

#import "Bit_Operations";
