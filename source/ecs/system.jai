
System_Func :: #type (world: *World);

System :: struct {
    func: System_Func;

    debug_name: string;

    run_before: [..] System_Func;
    run_after: [..] System_Func;
}

System_Scheduler :: struct {
    systems: [..] System;

    /** Maps system index to indicies of systems which depend on it to complete */
    dependencies: [..][..] s64;
    /** Each system maps to a number indicating how many more systems that it depend on have not yet completed. */
    wait_count_template: [..] s64;

    /** Has the dependency graph been built for this scheduler? */
    built := false;
}

System_Phase :: enum u32{
    INIT;
    SIMULATE;
    PRESENT;
    CLEANUP;
    NUM;
}

system_groups: [System_Phase.NUM] System_Scheduler;

add_system :: (scheduler: *System_Scheduler, func: System_Func, run_after: [] System_Func = .[], run_before: [] System_Func = .[], $call := #caller_code) {
    system := array_add(*scheduler.systems);
    system.func = func;
    system.debug_name = #run -> string {
        nodes := compiler_get_nodes(call);

        assert(nodes.kind == .PROCEDURE_CALL);

        proc_call := cast(*Code_Procedure_Call) nodes;

        if proc_call.arguments_sorted[1].kind != .IDENT {
            return "";
        }

        ident := cast(*Code_Ident) proc_call.arguments_sorted[1];

        return ident.name;
    };

    log("Registered system: %", system.debug_name);

    array_copy(*system.run_before, run_before);
    array_copy(*system.run_after, run_after);

    scheduler.built = false;
}

execute :: (world: *World, scheduler: *System_Scheduler) {
    if scheduler.built == false {
        build_dependency_graph(scheduler);
    }
    found_one := false;

    systems_to_run: [..] s64;
    systems_to_run.allocator = temp;
    array_resize(*systems_to_run, scheduler.systems.count);
    for 0..scheduler.systems.count-1 {
        systems_to_run[it] = it;
    }

    // copy the wait_count_template into a local copy that we can modify as the systems execute.
    wait_count: [..] s64;
    wait_count.allocator = temp;
    array_copy(*wait_count, scheduler.wait_count_template);

    while systems_to_run.count > 0 {
        found_one = false;

        for systems_to_run {
            system_index := it;

            // if the system is runnable now:
            if wait_count[system_index] == 0 {
                scheduler.systems[system_index].func(world);

                // signal to dependents that we finished:
                for dependent : scheduler.dependencies[system_index] {
                    assert(wait_count[dependent] > 0);
                    wait_count[dependent] -= 1;
                }

                found_one = true;

                remove it;
            }
        }

        assert(found_one || systems_to_run.count == 0);
    }
}

#scope_file

build_dependency_graph :: (scheduler: *System_Scheduler) {
    find_system :: (systems: [] System, func: System_Func) -> bool, s64 {
        for systems if it.func == func then return true, it_index;
        return false, -1;
    }

    // Reset any existing data:
    assert(scheduler.dependencies.count == scheduler.wait_count_template.count);
    for 0..scheduler.dependencies.count-1 {
        array_reset(*scheduler.dependencies[it]);
        scheduler.wait_count_template[it] = 0;
    }

    array_resize(*scheduler.dependencies, scheduler.systems.count);
    array_resize(*scheduler.wait_count_template, scheduler.systems.count);

    // build dependency map:
    for scheduler.systems {
        system_index := it_index;

        for dependee : it.run_after {
            found, index := find_system(scheduler.systems, dependee);
            if found {
                array_add(*scheduler.dependencies[index], system_index);
                scheduler.wait_count_template[system_index] += 1;
            }
        }

        for dependent : it.run_before {
            found, index := find_system(scheduler.systems, dependent);
            if found {
                array_add(*scheduler.dependencies[system_index], index);
                scheduler.wait_count_template[index] += 1;
            }
        }
    }

    scheduler.built = true;
}

#scope_export

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

    execute(*world, *scheduler);

    test_expect_equals(2, execution_count);

    test_expect_equals(102, c2.x);
} @UnitTest

#scope_file


Test :: struct {
    x: u32;
}

execution_count: u32 = 0;
