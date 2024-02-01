delta_time: float64 = 0.013;


PORT_NUMBER :: 25566;

main :: () {
    args := get_command_line_arguments();
    defer array_reset(*args);

    if args.count == 1 {
        log("Error: please indicate if running as server or client");
        return;
    }

    if !socket_init() {
        log_error("Failed to initialize sockets");
        return;
    }

    if args[1] == "client" {
        client_main();
    } else if args[1] == "server" {
        server_main();
    }
}

server_mutex: Mutex;
server_listen_socket: Socket;

server_main :: () {
    fd := socket(AF_INET, SOCK.STREAM, IPPROTO.TCP);

    if bind(fd, INADDR_ANY, PORT_NUMBER) == -1 {
        log_error("Failed to bind a server listen socket");
        return;
    }

    // listens for an incoming connection:
    if listen(fd, 1) != 0 {
        log_error("Listen error");
    }

    init(*server_mutex, "Server Mutex");

    server_listen_socket = fd;
}

server_loop :: () {

    // accepts the connection:
    cfd, addr := accept(server_listen_socket);

    log("Client connected on port %", addr.sin_port);

    set_blocking(cfd, false);

    buff: [1024] u8;
    num_bytes := recv(cfd, buff.data, buff.count, 0);

    assert(num_bytes > 0 );
    str: string;
    str.data = buff.data;
    str.count = num_bytes; 
    log("%", str);
}

client_main :: () {
    sfd := socket(AF_INET, SOCK.STREAM, IPPROTO.TCP);

    server_addr: sockaddr_in;
    server_addr.sin_family = AF_INET;

    c_addr := to_c_string("127.0.0.1");
    defer free(c_addr);

    addr := inet_addr(c_addr);

    #if OS == .WINDOWS {
        server_addr.sin_addr.S_un.S_addr = addr;
    } else {
        server_addr.sin_addr.s_addr = htonl(addr);
    }

    server_addr.sin_port = htons(PORT_NUMBER);

    return_code := connect(sfd, cast(*sockaddr)(*server_addr), size_of(sockaddr_in));
    if return_code != 0 {
        log_error("Failed to connect to server (error code %)", return_code);
        return;
    }

    set_blocking(sfd, false);

    test_string := "hello world";
    send(sfd, to_c_string(test_string), xx test_string.count, 0);

    /*
    window := create_window(800, 600, "Sapped");
    get_render_dimensions(window);
    set_render_target(window);

    should_exit := false;

    last_frame_time := seconds_since_init();

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

        {
            now := seconds_since_init();
            delta_time = (now - last_frame_time);
            last_frame_time = now;
        }

        simulate(delta_time);

        swap_buffers(window);
    }
    */
}


simulate :: (delta_time: float64) {

}



#import "Basic";
#import "Window_Creation";
#import "Simp";
#import "Input";
#import "Socket";
#import "Thread";