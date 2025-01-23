show_imgui_demo_window := false;
show_stats := true;
show_settings := false;
show_scene_graph := true;

render_debug_ui :: () {
    if ImGui.BeginMainMenuBar() {
        if ImGui.BeginMenu("Tools") {
            if ImGui.MenuItem("Settings", null, *show_settings) {}
            if ImGui.MenuItem("Stats", null, *show_stats) {}
            if ImGui.MenuItem("Scene Graph", null, *show_scene_graph) {}
            ImGui.EndMenu();
        }
        if ImGui.BeginMenu("Help") {
            ImGui.EndMenu();
        }
        ImGui.EndMainMenuBar();
    }

    if show_settings {
        show_settings_window();
    }
    if show_stats {
        show_stats_overlay();
    }
    if show_imgui_demo_window {
        ImGui.ShowDemoWindow(*show_imgui_demo_window);
    }
    if show_scene_graph {
        show_scene_graph_window(*show_scene_graph);
    }
}

show_settings_window :: () {
    if !ImGui.IsPopupOpen("Settings") {
        ImGui.OpenPopup("Settings");
    }
    if ImGui.BeginPopupModal("Settings", *show_settings, .AlwaysAutoResize | .NoMove) {
        ImGui.SliderFloat("UI Scale", *UI_SCALE, 0.5, 5.);
        ImGui.EndPopup();
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


        ImGui.NewLine();
        ImGui.Text("Networking Stats");
        ImGui.Checkbox("Client-Side Prediction", *g_enable_prediction);
        networking_stats := get_connection_stats();
        ImGui.Text("Server tick rate: % tps",  1. / FIXED_TIMESTEP);
        ImGui.Text("Ping: % ms", networking_stats.m_nPing);
        ImGui.PlotLines("Bytes Recv", networking_bytes_received_stats.data, cast(s32) networking_bytes_received_stats.count, graph_size = .{150, 0});
    }
    ImGui.End();
}

#load "scene_graph.jai";