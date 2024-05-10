Test :: struct {
    x: u32;
}


test_ecs_systems :: (ctx: *TestContext) {
    world: World;

    e1 := spawn_entity(*world);
    e2 := spawn_entity(*world);

    c2 := add_component(*world, e2, Test);

    run_all_systems(*world);

    test_expect_equals(c2, test_ptr);
    test_expect_equals(1, execution_count);
} @UnitTest

test_system :: (entity: Entity, test: *Test) {
    test_ptr = test;
    execution_count += 1;
} @System


test_system2 :: (world: *World) {
    
}

#scope_file

test_ptr: *Test = null;
execution_count: u32 = 0;

