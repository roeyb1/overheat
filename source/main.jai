delta_time: float64 = 0.013;

g_should_exit: bool = false;

main :: () {
    rendering_init();
    networking_init();

    last_time := seconds_since_init();

    while !g_should_exit {
        networking_update();

        rendering_begin_frame();

        // #todo: remove sleep
        sleep_milliseconds(16);

        now := seconds_since_init();
        delta_time = (now - last_time);
        last_time = now;

        simulate(delta_time);

        rendering_end_frame();

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();
    }

    networking_shutdown();
    rendering_shutdown();
}

simulate :: (delta_time: float64) {
    networking_send_packet(tprint("%s Ping", delta_time));

    networking_broadcast("Message from the server");
}


#import "Basic";
#import "Input";

#load "networking.jai";
#load "rendering.jai";