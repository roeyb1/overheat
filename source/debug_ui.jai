show_system_graph := false;
show_imgui_demo_window := false;
show_stats := false;

render_debug_ui :: () {
    if ImGui.BeginMainMenuBar() {
        if ImGui.BeginMenu("Tools") {
            if ImGui.MenuItem("Stats", null, *show_stats) {}
            if ImGui.MenuItem("View System Graph", null, *show_system_graph) {}
            ImGui.EndMenu();
        }
        if ImGui.BeginMenu("Help") {
            if ImGui.MenuItem("Show ImGui Demo", null, *show_imgui_demo_window) {}
            ImGui.EndMenu();
        }
        ImGui.EndMainMenuBar();
    }

    if show_stats {
        show_stats_overlay();
    }
    if show_system_graph {
        visualize_system_execution();
    }
    if show_imgui_demo_window {
        ImGui.ShowDemoWindow(*show_imgui_demo_window);
    }
}

show_stats_overlay :: () {
    viewport := ImGui.GetMainViewport();
    PADDING :: 10.;

    ImGui.SetNextWindowPos(viewport.WorkPos + .{PADDING, PADDING});

    ImGui.SetNextWindowBgAlpha(0.35);
    if ImGui.Begin("Stats", null, .NoMove | .NoDecoration | .AlwaysAutoResize | .NoSavedSettings | .NoFocusOnAppearing | .NoNav) {
        ImGui.TextUnformatted("Stats");
        ImGui.Separator();
        ImGui.Text("Average FPS: % (% ms)",  cast(u32)(1. / g_smooth_delta_time), formatFloat(g_smooth_delta_time * 1000., trailing_width = 2));
        ImGui.Text("Sim FPS: % (% ms)",  cast(u32)(1. / g_sim_timer), formatFloat(g_sim_timer * 1000., trailing_width = 2));
        ImGui.Text("Render FPS: % (% ms)",  cast(u32)(1. / g_render_timer), formatFloat(g_render_timer * 1000, trailing_width = 2));
    }
    ImGui.End();
}

visualize_system_execution :: () {
    PHASE_COLORS :: u32.[
        #run ImGui.IM_COL32(100, 20, 130),
        #run ImGui.IM_COL32(200, 50, 20),
        #run ImGui.IM_COL32(60, 80, 100),
        #run ImGui.IM_COL32(60, 100, 110),
        #run ImGui.IM_COL32(120, 80, 10),
        #run ImGui.IM_COL32(20, 123, 127),
        #run ImGui.IM_COL32(102, 92, 17),
        #run ImGui.IM_COL32(53, 72, 78),
        #run ImGui.IM_COL32(120, 30, 10),
    ];
    #assert(PHASE_COLORS.count == NUM_SYSTEM_PHASES);

    viewport := ImGui.GetMainViewport();

    ImGui.SetNextWindowPos(viewport.WorkPos);
    ImGui.SetNextWindowSize(viewport.WorkSize);
    if ImGui.Begin("System Execution", *show_system_graph, .NoResize | .NoMove | .NoSavedSettings) {
        ImNodes.BeginNodeEditor();

        phase_node_offset_y := 50.;
        for phase_index : 0..NUM_SYSTEM_PHASES-1 {
            phase_offset: s32 = cast(s32)(phase_index * 10000);
            input_offset: s32 : 1000;
            output_offset: s32 : 2000;

            phase_node_offset_x := 50.;

            scheduler := *system_groups[phase_index];

            max_node_width := 0.;
            max_node_height := 0.;
            phase_node_index := phase_offset;
            {
                ImNodes.PushColorStyle(.TitleBar, PHASE_COLORS[phase_index]);
                ImNodes.BeginNode(phase_node_index);

                ImNodes.BeginNodeTitleBar();
                ImGui.Text("Phase::%", type_info(System_Phase).names[phase_index]);
                ImNodes.EndNodeTitleBar();

                ImNodes.BeginOutputAttribute(output_offset + phase_node_index, .TriangleFilled);
                ImNodes.EndInputAttribute();

                ImNodes.EndNode();

                ImNodes.SetNodeDraggable(phase_node_index, false);
                ImNodes.SetNodeGridSpacePos(phase_node_index, .{phase_node_offset_x, phase_node_offset_y});
            
                node_dims := ImNodes.GetNodeDimensions(phase_node_index);
                max_node_width = max(node_dims.x, max_node_width);
                max_node_height = max(node_dims.y, max_node_height);
                phase_node_offset_x += node_dims.x + 50.;
                phase_node_offset_y += node_dims.y + 10.;

                ImNodes.PopColorStyle();
            }

            node_depths: [..] s32;
            node_depths.allocator = temp;
            array_resize(*node_depths, scheduler.systems.count);
            for 0..node_depths.count-1 {
                node_depths[it] = 0;
            }

            ImNodes.PushColorStyle(.TitleBar, PHASE_COLORS[phase_index]);

            for scheduler.systems {
                system_index := it_index;
                node_index := cast(s32) system_index + phase_offset + 1; 
            
                ImNodes.BeginNode(node_index);

                ImNodes.BeginNodeTitleBar();
                ImGui.Text("%", scheduler.systems[system_index].debug_name);
                ImNodes.EndNodeTitleBar();

                ImNodes.BeginInputAttribute(input_offset + node_index, .TriangleFilled);
                ImNodes.EndInputAttribute();

                // if no system depends on this one, we don't need an output attribute
                if scheduler.dependencies[system_index].count != 0 {
                    ImNodes.BeginOutputAttribute(output_offset + node_index, .TriangleFilled);
                    ImNodes.EndOutputAttribute();
                }

                if ImGui.BeginTable(temp_c_string(tprint("Components##%", node_index)), 2, .SizingFixedFit | .BordersInnerV) {
                        ImGui.TableNextRow();
                        ImGui.TableNextColumn();
                        ImGui.Text("READS");
                        ImGui.TableNextColumn();
                        ImGui.Text("WRITES");

                    for ctid_index : 0..max(it.def.component_reads.count, it.def.component_writes.count)-1 {
                        ImGui.TableNextRow();
                        ImGui.TableNextColumn();
                        if ctid_index < it.def.component_reads.count {
                            ImGui.Text("%", it.def.component_reads[ctid_index].debug_name);
                        } else {
                            ImGui.Text("");
                        }
                        ImGui.TableNextColumn();
                        if ctid_index < it.def.component_writes.count {
                            ImGui.Text("%", it.def.component_writes[ctid_index].debug_name);
                        } else {
                            ImGui.Text("");
                        }

                    }

                    ImGui.EndTable();
                }
                

                ImNodes.EndNode();

                node_dims := ImNodes.GetNodeDimensions(node_index);
                max_node_width = max(node_dims.x, max_node_width);
                max_node_height = max(node_dims.y, max_node_height);

                for dep_index : scheduler.dependencies[system_index] {
                    node_depths[dep_index] = max(node_depths[system_index] + 1, node_depths[dep_index]);
                }
            }

            height := 0;
            // reposition nodes by depth
            for scheduler.systems {
                system_index := it_index;
                node_index := cast(s32) system_index + phase_offset + 1; 

                ImNodes.SetNodeDraggable(node_index, false);
                ImNodes.SetNodeGridSpacePos(node_index, .{phase_node_offset_x + (50. + max_node_width) * node_depths[system_index], phase_node_offset_y + (max_node_height + 10) * height});
                height += 1;
            }


            link_index: s32 = phase_offset;
            for system, system_index : scheduler.systems {
                system_node_index := cast(s32) system_index + phase_offset + 1;

                // if this system has no dependencies, we link it to the node corresponding to the phase
                if scheduler.wait_count_template[system_index] == 0 {
                    ImNodes.Link(link_index, output_offset + phase_node_index, input_offset + system_node_index);
                    link_index += 1;
                }

                for dependent_index : scheduler.dependencies[system_index] {
                    dep_node_index := cast(s32) dependent_index + phase_offset + 1;
                    ImNodes.Link(link_index, output_offset + system_node_index, input_offset + dep_node_index);
                    link_index += 1;
                }
            }

            max_depth := 0;
            for 0..node_depths.count-1 {
                max_depth = max(max_depth, node_depths[it]);
            }

            phase_node_offset_x += (50 + max_node_width) * (max_depth + 1);
            phase_node_offset_y += (10 + max_node_height) * (height);

            ImNodes.PopColorStyle();
        }

        ImNodes.EndNodeEditor();
    }


    ImGui.End();
}

