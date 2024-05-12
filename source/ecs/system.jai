
System_Func :: #type (world: *World);

System :: struct {
    func: #type (world: *World);
}

System_Scheduler :: struct {
    // #todo: phase-based execution
    systems: [..] System;
}

System_Phase :: enum u32{
    INIT;
    SIMULATE;
    PRESENT;
    CLEANUP;
    NUM;
}

system_groups: [System_Phase.NUM] System_Scheduler;

add_system :: (scheduler: *System_Scheduler, func: System_Func, run_after: [] System_Func = .[], run_before: [] System_Func = .[]) {
    array_add(*scheduler.systems, .{func});
}

execute :: (world: *World, scheduler: System_Scheduler) {
    // #todo: more intelligent scheduling
    for scheduler.systems {
        it.func(world);
    }
}

// =========================================== TESTING ===========================================

test_ecs_systems :: (ctx: *TestContext) {
    test_system :: (world: *World) {
        execution_count += 1;
    }

    test_system2 :: (world: *World) {
        for Query(*Test).{world = world} {
            entity := it_index;

            it.test.x = 102;

            execution_count += 1;
        }
    }

    scheduler: System_Scheduler;
    add_system(*scheduler, test_system);
    add_system(*scheduler, test_system2);

    world: World;

    e1 := spawn_entity(*world);
    e2 := spawn_entity(*world);

    c2 := add_component(*world, e2, Test);
    c2.x = 101;

    execute(*world, scheduler);

    test_expect_equals(2, execution_count);

    test_expect_equals(102, c2.x);
} @UnitTest

#scope_file

Test :: struct {
    x: u32;
}

execution_count: u32 = 0;
