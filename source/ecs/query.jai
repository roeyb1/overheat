Query :: struct ($component_types: ..Type) {
    #insert #run generate_query_members(..component_types);
}

generate_query_members :: ($component_types: ..Type) -> string #compile_time {
    builder: String_Builder;
    defer free_buffers(*builder);
    for component_types {
        ti := cast(*Type_Info_Struct)it;
        print_to_builder(*builder, "%: *%;\n", to_lower_copy_new(ti.name), ti.name);
    }
    return builder_to_string(*builder);
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
    c2 := add_component(*world, e1, Test2);

    query: Query(Test, Test2);

    a, b := query;

    

    return;
} @UnitTest