g_window: *SDL_Window;

g_window_width: s32 = 1280;
g_window_height: s32 = 720;
g_window_resized_this_frame := true;

window_system_init :: () {
    SDL_Init(SDL_INIT_VIDEO);

    g_window = SDL_CreateWindow(temp_c_string(tprint("Overheat - %", ifx is_server() then "Server" else "Client")), SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, g_window_width, g_window_height, SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
    assert(g_window != null);
}

window_system_update :: () {
    event: SDL_Event;
    while SDL_PollEvent(*event) {
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

        consumed := imgui_process_sdl_event(*event);
        if !consumed {
            handle_window_input_event(*event);
        }
    }

    imgui_new_frame(g_window);
}

window_system_shutdown :: () {
    SDL_DestroyWindow(g_window);
    SDL_Quit();
}

get_mouse_cursor_pos :: () -> (x: s32, y: s32) {
    x, y: s32;
    SDL_GetMouseState(*x, *y);
    return x, y;
}

#scope_file
#import "SDL";