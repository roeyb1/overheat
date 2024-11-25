imgui_init :: () {
    ctx := ImGui.CreateContext();
    ImNodes.SetImGuiContext(ctx);
    ImNodes.CreateContext();

    init_style();

    // bind the imgui IO directly to the SDL keycodes. This just makes our life a bit easier without having to go from SDL -> our input -> ImGui
    io := ImGui.GetIO();
    io.KeyMap[ImGui.Key.Tab] = xx SDLK_TAB;
    io.KeyMap[ImGui.Key.LeftArrow] = xx SDL_SCANCODE_LEFT;
    io.KeyMap[ImGui.Key.RightArrow] = xx SDL_SCANCODE_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow] = xx SDL_SCANCODE_UP;
    io.KeyMap[ImGui.Key.DownArrow] = xx SDL_SCANCODE_DOWN;
    io.KeyMap[ImGui.Key.PageUp] = xx SDL_SCANCODE_PAGEUP;
    io.KeyMap[ImGui.Key.PageDown] = xx SDL_SCANCODE_PAGEDOWN;
    io.KeyMap[ImGui.Key.Home] = xx SDL_SCANCODE_HOME;
    io.KeyMap[ImGui.Key.End] = xx SDL_SCANCODE_END;
    io.KeyMap[ImGui.Key.Delete] = xx SDLK_DELETE;
    io.KeyMap[ImGui.Key.Backspace] = xx SDLK_BACKSPACE;
    io.KeyMap[ImGui.Key.Enter] = xx SDLK_RETURN;
    io.KeyMap[ImGui.Key.Escape] = xx SDLK_ESCAPE;
    io.KeyMap[ImGui.Key.A] = xx SDLK_a;
    io.KeyMap[ImGui.Key.C] = xx SDLK_c;
    io.KeyMap[ImGui.Key.V] = xx SDLK_v;
    io.KeyMap[ImGui.Key.X] = xx SDLK_x;
    io.KeyMap[ImGui.Key.Y] = xx SDLK_y;
    io.KeyMap[ImGui.Key.Z] = xx SDLK_z;

    io.SetClipboardTextFn = ImGui_ImplSdl_SetClipboardText;
    io.GetClipboardTextFn = ImGui_ImplSdl_GetClipboardText;
    io.ClipboardUserData = null;

    io.BackendFlags_ |= .HasMouseCursors;
    io.BackendFlags_ |= .HasSetMousePos;
    io.BackendFlags_ |= .RendererHasVtxOffset;

    wmInfo: SDL_SysWMinfo ;
    SDL_VERSION(*wmInfo.version);
    SDL_GetWindowWMInfo(g_window, *wmInfo);
    ImGui.GetMainViewport().PlatformHandleRaw = wmInfo.info.win.window;

    cursor_arrow = SDL_CreateSystemCursor(.ARROW);
    cursor_text_input = SDL_CreateSystemCursor(.IBEAM);
    cursor_move = SDL_CreateSystemCursor(.HAND);
    cursor_resize_ns = SDL_CreateSystemCursor(.SIZENS);
    cursor_resize_ew = SDL_CreateSystemCursor(.SIZEWE);
    cursor_resize_nesw = SDL_CreateSystemCursor(.SIZENESW);
    cursor_resize_nwse = SDL_CreateSystemCursor(.SIZENWSE);
}

imgui_shutdown :: () {
    ImNodes.DestroyContext();
    ImGui.DestroyContext();
}

/** Process an SDL event for ImGui. This function returns true if it consumes the event (should not be forwarded to the program) */
imgui_process_sdl_event :: (event: *SDL_Event) -> bool {
    io := ImGui.GetIO();

    // If ImGui took focus from our application, release all application key state
    if io.WantCaptureKeyboard {
        release_all_keys();
    }

    if event.type == {
        case SDL_MOUSEWHEEL;
            if event.wheel.y > 0 g_MouseWheel = 1;
            if event.wheel.y < 0 g_MouseWheel = -1;
            return io.WantCaptureMouse;
        case SDL_MOUSEBUTTONDOWN;
            if event.button.button == SDL_BUTTON_LEFT   g_MousePressed[0] = true;
            if event.button.button == SDL_BUTTON_RIGHT  g_MousePressed[1] = true;
            if event.button.button == SDL_BUTTON_MIDDLE g_MousePressed[2] = true;
            return io.WantCaptureMouse;
        case SDL_TEXTINPUT;
            io.AddInputCharactersUTF8(io, xx event.text.text.data);
            return io.WantCaptureKeyboard;
        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            //@@key := event.key.keysym.sym & ~SDLK_SCANCODE_MASK;
            key := event.key.keysym.sym & (xx ~(1<<30));
            io.KeysDown[key] = (event.type == SDL_KEYDOWN);
            kmod := SDL_GetModState();
            io.KeyShift = ((kmod & KMOD_SHIFT) != 0);
            io.KeyCtrl = ((kmod & KMOD_CTRL) != 0);
            io.KeyAlt = ((kmod & KMOD_ALT) != 0);
            io.KeySuper = ((kmod & KMOD_GUI) != 0);
            return io.WantCaptureKeyboard;
    }
    return false;
}

imgui_new_frame :: (window: *SDL_Window) {
    io := ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    w, h: s32;
    display_w, display_h: s32;
    SDL_GetWindowSize(window, *w, *h);
    SDL_GL_GetDrawableSize(window, *display_w, *display_h);
    io.DisplaySize = .{xx w, xx h};
    io.DisplayFramebufferScale = .{cast(float) display_w / w, cast(float) display_h / h};

    // Setup time step
    io.DeltaTime = g_delta_time;

    // Setup inputs
    // (we already got mouse wheel, keyboard keys & characters from SDL_PollEvent())
    mx, my: s32;
    mouseMask := SDL_GetMouseState(*mx, *my);
    if (SDL_GetWindowFlags(window) & SDL_WINDOW_MOUSE_FOCUS) {
        io.MousePos = .{xx mx, xx my};   // Mouse position, in pixels (set to -1,-1 if no mouse / on another screen, etc.)
    } else {
        io.MousePos = .{-FLOAT32_MAX,-FLOAT32_MAX};
    }

    io.MouseDown[0] = (g_MousePressed[0] || (mouseMask & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0);      // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = (g_MousePressed[1] || (mouseMask & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0);
    io.MouseDown[2] = (g_MousePressed[2] || (mouseMask & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0);
    g_MousePressed[0], g_MousePressed[1], g_MousePressed[2] = false, false, false;

    io.MouseWheel = g_MouseWheel;
    g_MouseWheel = 0.0;

    // Hide OS mouse cursor if ImGui is drawing it
    SDL_ShowCursor(xx (io.MouseDrawCursor == false));

    if ImGui.GetMouseCursor() == {
        case .Arrow;         SDL_SetCursor(cursor_arrow);
        case .TextInput;     SDL_SetCursor(cursor_text_input);
        case .Hand;          SDL_SetCursor(cursor_move);
        case .ResizeNS;      SDL_SetCursor(cursor_resize_ns);
        case .ResizeEW;      SDL_SetCursor(cursor_resize_ew);
        case .ResizeNESW;    SDL_SetCursor(cursor_resize_nesw);
        case .ResizeNWSE;    SDL_SetCursor(cursor_resize_nwse);
    }
}

ImNodes :: #import "imnodes";

#scope_file

g_MousePressed := bool.[false, false, false];
g_MouseWheel: float = 0.0;

cursor_arrow: *SDL_Cursor;
cursor_text_input: *SDL_Cursor;
cursor_move: *SDL_Cursor;
cursor_resize_ns: *SDL_Cursor;
cursor_resize_ew: *SDL_Cursor;
cursor_resize_nesw: *SDL_Cursor;
cursor_resize_nwse: *SDL_Cursor;

ImGui_ImplSdl_GetClipboardText :: (data: *void) -> *u8 #c_call {
    return SDL_GetClipboardText();
}

ImGui_ImplSdl_SetClipboardText :: (data: *void, text: *u8) #c_call {
    SDL_SetClipboardText(text);
}

init_style :: () {
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

#scope_export

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

style_color_text_highlight :: ImGui.ImVec4.{255. / 255., 231. / 255., 148. / 255., 1.};

style_color_surface :: ImGui.ImVec4.{ 0.059, 0.059, 0.059, 1. };
style_color_overlay_1 :: ImGui.ImVec4.{ 0.07, 0.07, 0.07, 1. };
style_color_overlay_2 :: ImGui.ImVec4.{ 0.117, 0.117, 0.117, 1. };
style_color_overlay_3 :: ImGui.ImVec4.{ 0.133, 0.133, 0.133, 1. };
style_color_overlay_4 :: ImGui.ImVec4.{ 0.177, 0.177, 0.177, 1. };
style_color_active :: ImGui.ImVec4.{ 0.3, 0.3, 0.3, 1. };

style_color_error :: ImGui.ImVec4.{ 0.8, 0.141, 0.113, 1. };
style_color_disabled :: ImGui.ImVec4.{ 1., 1., 1., 0.7 };

