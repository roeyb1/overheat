delta_time: float64 = 0.013;

should_exit: bool = false;

main :: () {
    networking_init();

    while !should_exit {
        networking_update();
        sleep_milliseconds(500);

        simulate(delta_time);

        // Reset temporary storage at the end of each frame
        reset_temporary_storage();
    }

    networking_shutdown();
}

simulate :: (delta_time: float64) {
    networking_send_packet(tprint("%s Ping", delta_time));

    networking_broadcast("Message from the server");
}


#import "Basic";
#import "Window_Creation";
#import "Simp";
#import "Input";

#load "networking.jai";