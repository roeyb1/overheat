
show_system_graph := false;
show_imgui_demo_window := false;

render_debug_ui :: () {
    if ImGui.BeginMainMenuBar() {
        if ImGui.BeginMenu("Tools") {
            if ImGui.MenuItem("View System Graph", null, *show_system_graph) {}
            ImGui.EndMenu();
        }
        if ImGui.BeginMenu("Help") {
            if ImGui.MenuItem("Show ImGui Demo", null, *show_imgui_demo_window) {}
            ImGui.EndMenu();
        }
        ImGui.EndMainMenuBar();
    }

    if show_system_graph {
        visualize_system_execution();
    }
    if show_imgui_demo_window {
        ImGui.ShowDemoWindow(*show_imgui_demo_window);
    }
}

visualize_system_execution :: () {
    ImGui.SetNextWindowSize(.{1000, 350}, .Appearing);
    if ImGui.Begin("System Execution", *show_system_graph) {
        ImNodes.BeginNodeEditor();
        
        scheduler := *system_groups[System_Phase.OnUpdate];
        if scheduler.built == false {
            build_dependency_graph(scheduler);
        }

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

        node_depths: [..] s64;
        node_depths.allocator = temp;
        array_resize(*node_depths, scheduler.systems.count);
        for 0..node_depths.count-1 {
            node_depths[it] = 0;
        }

        depth := 0;
        while systems_to_run.count > 0 {
            found_one := false;

            height := 0;
            for systems_to_run {
                system_index := it;

                // if the system is runnable now:
                if wait_count[system_index] == 0 {
                    node_index := cast(s32) system_index; 
                    ImNodes.BeginNode(node_index);

                    ImGui.Text("%", scheduler.systems[system_index].debug_name);

                    ImNodes.BeginInputAttribute(1000 + node_index, .TriangleFilled);
                    ImNodes.EndInputAttribute();
                    ImNodes.BeginOutputAttribute(2000 + node_index, .TriangleFilled);
                    ImNodes.EndOutputAttribute();

                    ImNodes.EndNode();

                    ImNodes.SetNodeDraggable(node_index, false);
                    ImNodes.SetNodeGridSpacePos(node_index, .{50. + 250 * max(node_depths[system_index], depth), 50. + 50 * height});

                    // signal to dependents that we finished:
                    for dependent : scheduler.dependencies[system_index] {
                        assert(wait_count[dependent] > 0);
                        wait_count[dependent] -= 1;
                        node_depths[dependent] = max(node_depths[dependent], node_depths[system_index] + 1);
                    }

                    found_one = true;

                    height += 1;
                    remove it;
                }
            }
            assert(found_one || systems_to_run.count == 0);

            depth += 1;
        }


        link_index: s32 = 0;
        for system, system_index : scheduler.systems {
            for dependent_index : scheduler.dependencies[system_index] {
                ImNodes.Link(link_index, cast(s32) (2000 + system_index), cast(s32) (1000 + dependent_index));
                link_index += 1;
            }
        }



        ImNodes.EndNodeEditor();
    }


    ImGui.End();
}

