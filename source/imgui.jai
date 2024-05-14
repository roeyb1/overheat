imgui_init :: () {
    ImGui.CreateContext();
    ImGui.StyleColorsDark();

    ImGui.GetIO().Fonts.AddFontFromFileTTF(ImGui.GetIO().Fonts, "assets/Roboto-Regular.ttf", 18);

    style := ImGui.GetStyle();

    {
        style.Colors[ImGui.Col.WindowBg] = style_color_surface;
        style.Colors[ImGui.Col.ChildBg] = style_color_overlay_2;
        style.Colors[ImGui.Col.TitleBg] = style_color_surface;
        style.Colors[ImGui.Col.TitleBgActive] = .{ 0.06, 0.06, 0.06, 1. };

        style.Colors[ImGui.Col.MenuBarBg] = style_color_overlay_2;
        style.Colors[ImGui.Col.PopupBg] = style_color_overlay_3;

        style.Colors[ImGui.Col.Tab] = style_color_surface;
        style.Colors[ImGui.Col.TabActive] = style_color_overlay_2;
        style.Colors[ImGui.Col.TabHovered] = style_color_overlay_2;
        style.Colors[ImGui.Col.TabUnfocused] = style_color_surface;
        style.Colors[ImGui.Col.TabUnfocusedActive] = style_color_overlay_2;

        style.Colors[ImGui.Col.FrameBg] = style_color_overlay_1;
        style.Colors[ImGui.Col.FrameBgHovered] = style_color_overlay_4;
        style.Colors[ImGui.Col.FrameBgActive] = style_color_active;

        style.Colors[ImGui.Col.Header] = style_color_overlay_4;
        style.Colors[ImGui.Col.HeaderActive] = style_color_active;
        style.Colors[ImGui.Col.HeaderHovered] = style_color_primary;

        style.Colors[ImGui.Col.Button] = style_color_overlay_4;
        style.Colors[ImGui.Col.ButtonHovered] = style_color_primary;
        style.Colors[ImGui.Col.ButtonActive] = style_color_primary_dark;

        style.Colors[ImGui.Col.Border] = style_color_overlay_4;
        style.Colors[ImGui.Col.Border].w = 0.8;

        style.Colors[ImGui.Col.CheckMark] = style_color_primary;
        style.Colors[ImGui.Col.SliderGrab] = style_color_primary;
        style.Colors[ImGui.Col.SliderGrabActive] = style_color_primary_dark;

        //style.Colors[ImGui.Col.DockingPreview] = style_color_primary;

        style.Colors[ImGui.Col.Separator] = style_color_active;
        style.Colors[ImGui.Col.Separator].w = 0.;
        style.Colors[ImGui.Col.SeparatorActive] = style_color_primary_light;
        style.Colors[ImGui.Col.SeparatorHovered] = style_color_primary;

        style.Colors[ImGui.Col.ResizeGripActive] = style_color_primary_dark;
        style.Colors[ImGui.Col.ResizeGripHovered] = style_color_primary;
        style.Colors[ImGui.Col.ResizeGrip] = style_color_primary_dark;
    }


    {
        style.TabRounding = 8;
        style.TabBorderSize = 0;

        style.FrameRounding = 6;
        style.FrameBorderSize = 1;
        style.FramePadding = .{4, 6};

        style.WindowRounding = 1;

        style.GrabMinSize = 6;
        style.GrabRounding = 3;

        style.PopupRounding = 3;

        style.WindowPadding = .{ 6, 6 };
        style.IndentSpacing = 25;
        style.ScrollbarSize = 14;

        style.CircleTessellationMaxError = 0.1;
    }
}

imgui_shutdown :: () {
    ImGui.DestroyContext();
}

#scope_file

style_color_white :: ImGui.ImVec4.{ 1., 1., 1., 1. };

style_color_orange :: ImGui.ImVec4.{ 0.819, 0.278, 0.007, 1. };
style_color_red :: ImGui.ImVec4.{ 0.764, 0.133, 0.058, 1. };
style_color_red_inactive :: ImGui.ImVec4.{ 0.764, 0.133, 0.058, 0.7 };
style_color_blue :: ImGui.ImVec4.{ 0.250, 0.474, 0.549, 1. };
style_color_blue_inactive :: ImGui.ImVec4.{ 0.250, 0.474, 0.549, 0.7 };
style_color_green :: ImGui.ImVec4.{ 0.596, 0.592, 0.101, 1. };
style_color_green_inactive :: ImGui.ImVec4.{ 0.596, 0.592, 0.101, 0.7 };

style_color_primary :: ImGui.ImVec4.{ 0.250, 0.474, 0.549, 1. };
style_color_primary_light :: ImGui.ImVec4.{ 0.439, 0.662, 0.631, 1. };
style_color_primary_dark :: ImGui.ImVec4.{ 0.066, 0.294, 0.372, 1. };

style_color_surface :: ImGui.ImVec4.{ 0.059, 0.059, 0.059, 1. };
style_color_overlay_1 :: ImGui.ImVec4.{ 0.07, 0.07, 0.07, 1. };
style_color_overlay_2 :: ImGui.ImVec4.{ 0.117, 0.117, 0.117, 1. };
style_color_overlay_3 :: ImGui.ImVec4.{ 0.133, 0.133, 0.133, 1. };
style_color_overlay_4 :: ImGui.ImVec4.{ 0.177, 0.177, 0.177, 1. };
style_color_active :: ImGui.ImVec4.{ 0.3, 0.3, 0.3, 1. };

style_color_error :: ImGui.ImVec4.{ 0.8, 0.141, 0.113, 1. };
style_color_disabled :: ImGui.ImVec4.{ 1., 1., 1., 0.7 };
