System_Func :: #type (q: Query);

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
     * PostUpdate occurs after we've validated the frame. We can respond to any changes in game logic or anything that is output from the Validate stage
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

System_Def :: struct {
    func: System_Func;
    debug_name: string;

    phase: System_Phase;

    component_reads: [] Type;
    component_writes: [] Type;
    optional_writes: [] Type;

    archetype: [..] s64;

    is_predicted: bool;
}

System_Scheduler :: struct {
    systems: [..] System;

    /** Maps system index to indicies of systems which depend on it to complete */
    dependencies: [..][..] s64;

    /** Maps system index to indicies of systems which it depends on before it can run (inverse of dependencies) */
    inv_dependencies: [..][..] s64;
    /**
     * Each system maps to a number indicating how many more systems that it depend on have not yet completed.
     * This array is used as a template that can be copied every time this graph executes to avoid having to recompute the values each time.
     */
    wait_count_template: [..] s64;
}

system_groups: [NUM_SYSTEM_PHASES] System_Scheduler;

add_system :: (world: *World, phase: System_Phase, def: *System_Def) {
    scheduler := *system_groups[phase];
    system := array_add(*scheduler.systems);
    system.def = def;

    array_append(*def.archetype, cids_from_types(world, def.component_writes));
    array_append(*def.archetype, cids_from_types(world, def.component_reads));

    // remove any singleton components from the archetype so we can still declare them in the component usages but they don't get included in the archetype iterators:
    for cid : def.archetype {
        cti := cid_to_type_info(world, cid);
        if cti.is_singleton then remove cid;
    }

    quick_sort(def.archetype, (x) => x);

    log("Registered system: %", system.debug_name);
}

execute :: (world: *World, phase: System_Phase) {
    scheduler := *system_groups[phase];
    assert(scheduler.dependencies.count == scheduler.systems.count, "System graph attempted to execute before it was built!");
    execute_(world, scheduler);
}

build_system_dependency_graphs :: () {
    for * scheduler : system_groups {
        build_dependency_graph(scheduler);
    }
}

NUM_SYSTEM_PHASES :: #run enum_highest_value(System_Phase) + 1;

/** List of all system definitions, generated at compile time. */
#placeholder ALL_SYSTEMS;

is_sim_phase :: inline (phase: System_Phase) -> bool {
    if phase == {
        case .PreUpdate; #through;
        case .OnUpdate; #through;
        case .OnValidate; #through;
        case .PostUpdate;
            return true;
    }
    return false;
}

register_system_functions :: (world: *World) {
    for * ALL_SYSTEMS {
        #if CLIENT {
            if !is_sim_phase(it.phase) || it.is_predicted then add_system(world, it.phase, it);
        } else {
            add_system(world, it.phase, it);
        }
    }
    build_system_dependency_graphs();
}

#scope_file

System :: struct {
    using def: *System_Def;

    run_before: [..] System_Func;
    run_after: [..] System_Func;
}

build_dependency_graph :: (scheduler: *System_Scheduler) {
    find_system :: (systems: [] System, func: System_Func) -> bool, s64 {
        for systems if it.func == func then return true, it_index;
        return false, -1;
    }

    for * system : scheduler.systems {
        write_dependencies: [..] Type;
        write_dependencies.allocator = temp;

        array_append(*write_dependencies, system.component_writes);
        array_append(*write_dependencies, system.optional_writes);

        for write_dep : write_dependencies {
            for * other : scheduler.systems {
                if system == other then continue;
                other_reads := array_find(other.component_reads, write_dep);
                if other_reads {
                    array_add(*system.run_before, other.func);
                }
            }
        }
    }

    // Reset any existing data:
    assert(scheduler.dependencies.count == scheduler.wait_count_template.count);
    for 0..scheduler.dependencies.count-1 {
        array_reset(*scheduler.dependencies[it]);
        scheduler.wait_count_template[it] = 0;
    }

    array_resize(*scheduler.dependencies, scheduler.systems.count);
    array_resize(*scheduler.inv_dependencies, scheduler.systems.count);
    array_resize(*scheduler.wait_count_template, scheduler.systems.count);

    // build dependency map:
    for scheduler.systems {
        system_index := it_index;

        for dependee : it.run_after {
            found, index := find_system(scheduler.systems, dependee);
            if found {
                array_add(*scheduler.dependencies[index], system_index);
                array_add(*scheduler.inv_dependencies[system_index], index);
                scheduler.wait_count_template[system_index] += 1;
            }
        }

        for dependent : it.run_before {
            found, index := find_system(scheduler.systems, dependent);
            if found {
                array_add(*scheduler.dependencies[system_index], index);
                array_add(*scheduler.inv_dependencies[index], system_index);
                scheduler.wait_count_template[index] += 1;
            }
        }
    }
}


execute_ :: (world: *World, scheduler: *System_Scheduler) {
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

    world.is_deferring = true;
    while systems_to_run.count > 0 {
        found_one = false;

        for systems_to_run {
            system_index := it;

            // if the system is runnable now:
            if wait_count[system_index] == 0 {
                execute_system(scheduler.systems[system_index], world);

                // signal to dependents that we finished:
                for dependent : scheduler.dependencies[system_index] {
                    assert(wait_count[dependent] > 0);
                    wait_count[dependent] -= 1;
                }

                found_one = true;

                remove it;
            }
        }

        if !ensure(found_one || systems_to_run.count == 0, "System executor deadlocked! Is there a cyclic dependency in the system graph?") {
            break;
        }
    }

    world.is_deferring = false;
    process_deferred_operations(world);
}

execute_system :: (sys: System, world: *World) {
    query: Query;
    query.world = world;

    // special case systems with no components to iterate over. These should only execute one single time and don't have an archetype
    if sys.archetype.count == 0 {
        query.current_archetype = null;
        query.entities = .[];
        query.count = 1;

        sys.def.func(query);
    } else {
        archtype_ids := archetype_cache_find_or_create(*world.stage, sys.archetype);

        for archtype_ids {
            archetype := *world.stage.archetypes[it];
            #if CLIENT {
                if g_only_simulate_local_player && archetype_types_match(archetype, .[cid_get(world, Networked)]) && !archetype_types_match(archetype, .[cid_get(world, Local_Player)]) {
                    continue;
                }
            }

            query.current_archetype = archetype;
            query.entities = archetype.entities;
            query.count = archetype.entities.count;
            query.types = sys.archetype;

            sys.def.func(query);
        }
    }
}

#scope_export

g_only_simulate_local_player := false;
