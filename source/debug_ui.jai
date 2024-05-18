
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

        node_depths: [..] s32;
        node_depths.allocator = temp;
        array_resize(*node_depths, scheduler.systems.count);

        for scheduler.systems {
            system_index := it_index;
            for dep_index : scheduler.dependencies[system_index] {
                node_depths[dep_index] = max(node_depths[system_index] + 1, node_depths[dep_index]);
            }
        }

        height := 0;
        for scheduler.systems {
            system_index := it_index;
            node_index := cast(s32) system_index; 
            ImNodes.BeginNode(node_index);

            ImGui.Text("%", scheduler.systems[system_index].debug_name);

            ImNodes.BeginInputAttribute(1000 + node_index, .TriangleFilled);
            ImNodes.EndInputAttribute();
            ImNodes.BeginOutputAttribute(2000 + node_index, .TriangleFilled);
            ImNodes.EndOutputAttribute();

            ImNodes.EndNode();

            ImNodes.SetNodeDraggable(node_index, false);
            ImNodes.SetNodeGridSpacePos(node_index, .{50. + 250 * node_depths[system_index], 50. + 50 * height});
            height += 1;
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

