#scope_export

g_unit_test_functions: [..] #type () -> bool;

execute_unit_tests :: () -> bool {
    register_unit_tests();

    push_allocator(temp);

    result := true;
    for g_unit_test_functions {
        result &= it();
    }

    return result;
}