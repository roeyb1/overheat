Query :: struct ($component_types: ..Type) {
    #insert #run generate_query_members(..component_types);

    world: *World;
}

generate_query_members :: ($component_types: ..Type) -> string #compile_time {
    builder: String_Builder;
    defer free_buffers(*builder);
    for component_types {
        ti := cast(*Type_Info_Struct)it;
        print_to_builder(*builder, "%: *% = null;\n", to_lower_copy_new(ti.name), ti.name);
    }
    return builder_to_string(*builder);
}

for_expansion :: (query: Query, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.
    #assert(!(flags & .POINTER)); // we don't handle the pointer flag either.

    assert(query.world != null);

    for entity : query.world.entities {
        #insert #run () -> string {
            builder: String_Builder;
            defer free_buffers(*builder);
            
            print_to_builder(*builder, "matches_query := true");
            for query.component_types {
                ti := cast(*Type_Info_Struct)it;
                print_to_builder(*builder, " && get_component(query.world, entity, %)", ti.name);
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
            
            for query.component_types {
                ti := cast(*Type_Info_Struct)it;
                print_to_builder(*builder, "query.% = get_component(query.world, entity, %);\n", to_lower_copy_new(ti.name), ti.name);
            }
            return builder_to_string(*builder);
        }();

        `it := query;
        `it_index := entity;

        #insert body;
    }
}

#scope_file

Test :: struct {
    x: u32;
}

Test2 :: struct {
    x: u32;
}

#scope_export

test_ecs_query :: (ctx: *TestContext) {
    world: World;

    e1 := spawn_entity(*world);
    c1 := add_component(*world, e1, Test);
    c1.x = 11;
    c2 := add_component(*world, e1, Test2);
    c2.x = 12;

    e2 := spawn_entity(*world);
    add_component(*world, e2, Test);

    num_iters := 0;
    for Query(Test, Test2).{world = *world} {
        entity := it_index;

        test_assert_not_equals(null, it.test);
        test_expect_equals(11, it.test.x);
        test_assert_not_equals(null, it.test2);
        test_expect_equals(12, it.test2.x);

        num_iters += 1;
    }

    test_expect_equals(1, num_iters);
} @UnitTest