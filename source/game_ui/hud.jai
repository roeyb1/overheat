draw_player_action_bar :: (q: Query) {
    // @todo: hook this into skill system when it's ready
    NUM_SKILLS :: 5;

    SKILL_BUTTON_SIZE :: #run ui_size(.{25, 25});

    BAR_OFFSET :: #run ui_size(.{0, -1});

    skill_icon := get_texture("assets/ui/arrow_nova_skill.png");

    bar_width := (ImGui.GetStyle().FramePadding.x + ImGui.GetStyle().ItemSpacing.x + SKILL_BUTTON_SIZE.x) * NUM_SKILLS;

    window_size := ImGui.ImVec2.{cast(float)g_window_width, cast(float)g_window_height};
    ImGui.SetNextWindowPos(.{ (window_size.x - bar_width) / 2. + ImGui.GetStyle().ItemSpacing.x, window_size.y - (SKILL_BUTTON_SIZE.y + 2 * ImGui.GetStyle().FramePadding.y + 2 * ImGui.GetStyle().WindowPadding.y) + BAR_OFFSET.y});

    if ImGui.Begin("##ActionBar", null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
        for 0..NUM_SKILLS-1 {
            ImGui.ImageButton(temp_c_string(tprint("%##ActionBarSkill", it)), cast(ImGui.ImTextureID) get_texture_view_handle(skill_icon), SKILL_BUTTON_SIZE);
            ImGui.SameLine();
        }
    }
    ImGui.End();
} @System(PreRender) @Write() @Read()

draw_player_health :: (q: Query) {
    healths := query_get(q, Health);

    window_size := ImGui.ImVec2.{cast(float)g_window_width, cast(float)g_window_height};

    HEALTH_BAR_SIZE :: #run ui_size(.{100, 100});

    style := ImGui.GetStyle();

    for 0..q.count-1 {
        ImGui.SetNextWindowPos(.{style.FramePadding.x + style.WindowPadding.y, window_size.y - (HEALTH_BAR_SIZE.y + style.WindowPadding.y + 2 * style.FramePadding.y)});
        if ImGui.Begin("HUDHealthBar", null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
            ImGui.PushStyleColor(.PlotHistogram, HEALTH_COLOR);
            ImGui.ProgressBar(healths[it].value / healths[it].max, HEALTH_BAR_SIZE, "");
            ImGui.PopStyleColor();
        }
        ImGui.End();

        ImGui.SetNextWindowPos(.{window_size.x - (HEALTH_BAR_SIZE.x + style.FramePadding.x + 2 * style.WindowPadding.y), window_size.y - (HEALTH_BAR_SIZE.y + style.WindowPadding.y + 2 * style.FramePadding.y)});

        if ImGui.Begin("HUDResourceBar", null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
            ImGui.PushStyleColor(.PlotHistogram, RESOURCE_COLOR);
            ImGui.ProgressBar(healths[it].value / healths[it].max, HEALTH_BAR_SIZE, "");
            ImGui.PopStyleColor();
        }
        ImGui.End();
    }

} @System(PreRender) @Write() @Read(Local_Player,Health)