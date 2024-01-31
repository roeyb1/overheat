main :: () {
    window := create_window(800, 600, "Sapped");
    get_render_dimensions(window);
    set_render_target(window);

    should_exit := false;

    while !should_exit {
        update_window_events();

        for get_window_resizes() {
            update_window(it.window);

            if it.window == window {
                // #todo: handle main window resize
            }
        }

        for events_this_frame {
            if it.type == .QUIT then should_exit = true;
        }


        clear_render_target(.1, .1, .1, 1.);

        swap_buffers(window);
    }
}

#import "Basic";
#import "Window_Creation";
#import "Simp";
#import "Input";