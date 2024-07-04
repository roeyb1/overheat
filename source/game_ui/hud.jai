draw_player_action_bar :: (q: Query) {
    // @todo: hook this into skill system when it's ready
    NUM_SKILLS :: 5;

    SKILL_BUTTON_SIZE :: #run ui_size(.{30, 30});

    BAR_OFFSET :: #run ui_size(.{0, -5});

    bar_width := (ImGui.GetStyle().FramePadding.x + ImGui.GetStyle().ItemSpacing.x + SKILL_BUTTON_SIZE.x) * NUM_SKILLS;

    window_size := ImGui.ImVec2.{cast(float)g_window_width, cast(float)g_window_height};
    ImGui.SetNextWindowPos(.{ (window_size.x - bar_width) / 2. + ImGui.GetStyle().ItemSpacing.x, window_size.y - (SKILL_BUTTON_SIZE + ImGui.GetStyle().FramePadding).y + BAR_OFFSET.y });

    if ImGui.Begin("##ActionBar", null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
        for 0..NUM_SKILLS-1 {
            ImGui.Button(temp_c_string(tprint("%", it)), SKILL_BUTTON_SIZE);
            ImGui.SameLine();
        }
    }
    ImGui.End();
} @System(PreRender) @Write() @Read()