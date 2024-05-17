System_Func :: #type (world: *World);

/**
 * Every system must be placed into a specific phase to ensure that systems that 
 * need to be executed before others have a convenient way to do so. 
 * More fine-grained control is possible through explicit run_before/run_after dependencies but as much as possible it is best to avoid that.
 */
System_Phase :: enum u32{
    /**
     * Init is the earliest execution point in the system pipeline.
     * Useful for things that initialize data that must be available before all other phases.
     */
    Init;

    /**
     * OnLoad loads external data into the ECS.
     * Useful for initializing system time, user input, etc.
     */
    OnLoad;

    /**
     * PostLoad runs after we load data and allows processing that imported data. 
     * Translating key presses into input events is an example of a system that should go in this phase.
     */
    PostLoad;

    /**
     * Once all our external data is loaded an processed, we can run any cleanup/processing that has to happen before game logic runs.
     */
    PreUpdate;

    /**
     * The majority of game logic should go here!
     */
    OnUpdate;

    /**
     * OnValidate allows systems to validate the current state of the game after game logic runs.
     * This is where collision detection will occur
     */
    OnValidate;

    /**
     * 
     * Examples: 
     * - Collision resolution will occur here.
     * - Characters with 0 health will be destroyed here
     * - Projectiles/particles that have expended their lifetimes will also die here.
     */
    PostUpdate;

    /**
     * Prepare and build any required data for rendering.
     */
    PreRender;

    /**
     * Rendering happens here!
     */
    OnRender;
}

System_Scheduler :: struct {
    systems: [..] System;

    /** Maps system index to indicies of systems which depend on it to complete */
    dependencies: [..][..] s64;
    /**
     * Each system maps to a number indicating how many more systems that it depend on have not yet completed.
     * This array is used as a template that can be copied every time this graph executes to avoid having to recompute the values each time.
     */
    wait_count_template: [..] s64;

    /** Has the dependency graph been built for this scheduler? */
    built := false;
}

system_groups: [NUM_SYSTEM_PHASES] System_Scheduler;

add_system :: (phase: System_Phase, func: System_Func, run_after: [] System_Func = .[], run_before: [] System_Func = .[], $call := #caller_code) {
    scheduler := *system_groups[phase];
    debug_name := #run -> string {
        nodes := compiler_get_nodes(call);

        assert(nodes.kind == .PROCEDURE_CALL);

        proc_call := cast(*Code_Procedure_Call) nodes;

        if proc_call.arguments_sorted[1].kind != .IDENT {
            return "";
        }

        ident := cast(*Code_Ident) proc_call.arguments_sorted[1];

        return ident.name;
    };
    add_system_(scheduler, func, run_after, run_before, debug_name);
}

execute :: (world: *World, phase: System_Phase) {
    scheduler := *system_groups[phase];
    execute_(world, scheduler);
}

#scope_file

NUM_SYSTEM_PHASES :: #run enum_highest_value(System_Phase) + 1;

System :: struct {
    func: System_Func;

    debug_name: string;

    run_before: [..] System_Func;
    run_after: [..] System_Func;
}

execute_ :: (world: *World, scheduler: *System_Scheduler) {
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

add_system_ :: (scheduler: *System_Scheduler, func: System_Func, run_after: [] System_Func = .[], run_before: [] System_Func = .[], debug_name: string = "") {
    system := array_add(*scheduler.systems);
    system.func = func;
    system.debug_name = debug_name;

    log("Registered system: %", system.debug_name);

    array_copy(*system.run_before, run_before);
    array_copy(*system.run_after, run_after);

    scheduler.built = false;
}

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
    add_system_(*scheduler, test_system);
    add_system_(*scheduler, test_system2);

    world: World;

    e1 := spawn_entity(*world);
    e2 := spawn_entity(*world);

    c2 := add_component(*world, e2, Test);
    c2.x = 101;

    execute_(*world, *scheduler);

    test_expect_equals(2, execution_count);

    test_expect_equals(102, c2.x);
} @UnitTest

#scope_file


Test :: struct {
    x: u32;
}

execution_count: u32 = 0;
