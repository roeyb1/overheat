g_window: *SDL_Window;

g_window_width: s32 = 1280;
g_window_height: s32 = 720;
g_window_resized_this_frame := true;

window_system_init :: () {
    SDL_Init(SDL_INIT_VIDEO);

    g_window = SDL_CreateWindow("Overheat", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, g_window_width, g_window_height, SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
    assert(g_window != null);

    ImGui_ImplSdl_Init(g_window);

    ImGui.GetIO().Fonts.AddFontFromFileTTF(ImGui.GetIO().Fonts, "assets/Roboto-Regular.ttf", 18);
}

window_system_update :: () {
    event: SDL_Event;
    while SDL_PollEvent(*event) {
        ImGui_ImplSdl_ProcessEvent(*event);
        if event.type == SDL_QUIT then g_should_exit = true;
        if event.type == SDL_WINDOWEVENT && event.window.windowID == SDL_GetWindowID(g_window) {
            if event.window.event == SDL_WINDOWEVENT_CLOSE {
                g_should_exit = true;
            }
            if event.window.event == SDL_WINDOWEVENT_RESIZED {
                g_window_width = xx event.window.data1;
                g_window_height = xx event.window.data2;

                g_window_resized_this_frame = true;
            }
        }
    }

    ImGui_ImplSdl_NewFrame(g_window);
}

window_system_prerender :: () {
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

window_system_shutdown :: () {
    SDL_DestroyWindow(g_window);
    SDL_Quit();
}

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

ImGui_ImplSdl_Init :: (window: *SDL_Window) -> bool {
    io := ImGui.GetIO();
    io.KeyMap[ImGui.Key.Tab] = xx SDLK_TAB;                     // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
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

    wmInfo: SDL_SysWMinfo ;
    SDL_VERSION(*wmInfo.version);
    SDL_GetWindowWMInfo(window, *wmInfo);
    ImGui.GetMainViewport().PlatformHandleRaw = wmInfo.info.win.window;

    cursor_arrow = SDL_CreateSystemCursor(.ARROW);
    cursor_text_input = SDL_CreateSystemCursor(.IBEAM);
    cursor_move = SDL_CreateSystemCursor(.HAND);
    cursor_resize_ns = SDL_CreateSystemCursor(.SIZENS);
    cursor_resize_ew = SDL_CreateSystemCursor(.SIZEWE);
    cursor_resize_nesw = SDL_CreateSystemCursor(.SIZENESW);
    cursor_resize_nwse = SDL_CreateSystemCursor(.SIZENWSE);

    return true;
}

ImGui_ImplSdl_GetClipboardText :: (data: *void) -> *u8 #c_call {
    return SDL_GetClipboardText();
}

ImGui_ImplSdl_SetClipboardText :: (data: *void, text: *u8) #c_call {
    SDL_SetClipboardText(text);
}

ImGui_ImplSdl_ProcessEvent :: (event: *SDL_Event) -> bool {
    io := ImGui.GetIO();
    if event.type == {
        case SDL_MOUSEWHEEL;
            if event.wheel.y > 0 g_MouseWheel = 1;
            if event.wheel.y < 0 g_MouseWheel = -1;
            return true;
        case SDL_MOUSEBUTTONDOWN;
            if event.button.button == SDL_BUTTON_LEFT   g_MousePressed[0] = true;
            if event.button.button == SDL_BUTTON_RIGHT  g_MousePressed[1] = true;
            if event.button.button == SDL_BUTTON_MIDDLE g_MousePressed[2] = true;
            return true;
        case SDL_TEXTINPUT;
            io.AddInputCharactersUTF8(io, xx event.text.text.data);
            return true;
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
            return true;
    }
    return false;
}

ImGui_ImplSdl_NewFrame :: (window: *SDL_Window) {
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
}
#import "SDL";