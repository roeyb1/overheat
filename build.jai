
build :: () {
    //
    // Create a workspace to contain the program we want to compile.
    // We can pass a name to compiler_create_workspace that gets reported
    // back to us in error messages:
    //
    w := compiler_create_workspace("Overheat");
    if !w {
        log_error("Workspace creation failed.\n");
        return;
    }

    args := get_build_options().compile_time_command_line;

    options := get_build_options(w);
    options.output_executable_name = "overheat";

    // Set up the output directory based on the target operating system:
    {
        // bin folder should contain per-os subdirs:
        if options.os_target == {
            case .WINDOWS;
                options.output_path = "bin/win";
            case .LINUX;
                options.output_path = "bin/linux";
            case .MACOS;
                options.output_path = "bin/macos";
        }

        make_directory_if_it_does_not_exist(options.output_path, recursive=true);
    }

    do_initial_cwd   := true;
    check_bindings   := true;
    do_check         := true;  // Import modules/Check if true.

    printed_help    := false;
    printed_version := false;

    modules_paths: [..] string;

    plugin_names:  [..] string;
    plugin_names2: [..] string;

    user_arguments: [..] string;

    index := 0;

    //
    // First we do a pass where we scan for -plug arguments, and import those plugins.
    // Why? So that the plugins can handle unknown arguments and the like.
    // Note that it is not strictly correct to scan for -plug since theoretically
    // the string -plug could be an argument to some other option. Even though this isn't
    // realistically a problem, it feels bad, so we at least check for it in pass 2,
    // which is what plugin_names2 is for -- we make sure during pass 2 that we get
    // the same results as pass 1.
    //

    while index < args.count {
        defer index += 1;

        it := args[index];
        if it == {
            case "-plugin"; #through;
            case "-plug";
                if index >= args.count-1 {
                    break;  // Silent. We'll catch this the second time around.
                }

                index += 1;
                array_add(*plugin_names, args[index]);

            // We need to know about this in the first pass to add the tracy plugin. We will enable optimizations in pass 2
            case "-profile";
                array_add(*plugin_names, "tracy");

            case "-ps5";
                array_add(*plugin_names, "ps5_build");

            // We need to know about no_check bindings in pass 1 because that is how we determine if that plugin is in the set! Argh.
            case "-no_check";           do_check = false;
            case "-no_check_bindings";  check_bindings = false;
            case "-check_bindings";     check_bindings = true; // Not necessary anymore since we changed the default. I just left it in for backwards compatibility. -rluba, 2022-03-23
            case "-";  // Do not process anything after -!
                break;
        }
    }

    if do_check {
        if check_bindings array_add(*plugin_names, "Check");
        else              array_add(*plugin_names, "Check(CHECK_BINDINGS=false)");
    }

    // Now that we know what the plugins are, init them.
    init_plugins(plugin_names, *plugins, w);


    //
    // Pass 2: Handle all the various options, or delegate them to plugins
    // if we do not handle them.
    //
    index = 0;  // Starting over!
    got_user_arguments_delimiter := false;
    got_error       := false;

    output_executable_name: string;
    output_path:            string;

    enable_rhi_validation := false;
    enable_vulkan_debug := false;
    enable_shader_comp := false;

    intercept_flags: Intercept_Flags;

    while index < args.count {
        defer index += 1;

        it := args[index];

        if got_user_arguments_delimiter {
            array_add(*user_arguments, it);
            continue;
        }

        if !it continue;

        if it[0] == #char "-" {
            if it == {
            case "-";
                // Everything after this is user arguments.
                got_user_arguments_delimiter = true;
            
            case "-rhivalidation";
                enable_rhi_validation = true;

            case "-vkdebug";
                enable_vulkan_debug = true;
            case "-compileshaders";
                enable_shader_comp = true;
            case "-release";
                set_optimization(*options, .OPTIMIZED);
                options.stack_trace = false;

            case "-profile";
                set_optimization(*options, .OPTIMIZED);
                options.stack_trace = false;
                array_add(*plugin_names2, "tracy");

            case "-very_debug";
                set_optimization(*options, .VERY_DEBUG);

            case "-quiet";
                options.text_output_flags = 0;

            case "-x64";
                options.backend = .X64;
            case "-llvm";
                options.backend = .LLVM;

            case "-no_dce";
                options.dead_code_elimination = .NONE;

            case "-no_split";
                options.llvm_options.enable_split_modules = false;

            case "-output_ir";
                options.llvm_options.output_llvm_ir_before_optimizations = true;
                options.llvm_options.output_llvm_ir = true;

            case "-debug_for";
                options.debug_for_expansions = true;

            case "-msvc_format";
                options.use_visual_studio_message_format = true;

            case "-natvis";
                options.use_natvis_compatible_types = true;

            case "-no_check";           // nop; we handled this in pass 1.
            case "-no_check_bindings";  // nop; we handled this in pass 1.
            case "-check_bindings";     // nop; we handled this in pass 1.

            case "-no_backtrace_on_crash";
                options.backtrace_on_crash = .OFF;

            case "-plugin"; #through;
            case "-plug";
                if index >= args.count-1 {
                    log_error("Command line: Missing argument to %.\n", it);
                    got_error = true;
                    break;
                }

                index += 1;
                array_add(*plugin_names2, args[index]);  // So we can check this later.

            case "-ps5";
                array_add(*plugin_names2, "ps5_build");

            case "-help"; #through;
            case "-?";
                log("%", HELP_STRING);

                printed_help = true;

            case "-debugger";
                options.interactive_bytecode_debugger = true;

            case "-import_dir";
                if index >= args.count-1 {
                    log_error("Command line: Missing argument to -import_dir.\n");
                    got_error = true;
                    break;
                }

                index += 1;
                array_add(*modules_paths, args[index]);

            case "-no_color";
                options.use_ansi_color = false;

            case "-verbose";
                verbose = true;

            case;
                handled := false;
                for p, plugin_index: plugins {
                    if !p.handle_one_option continue;

                    new_index := p.handle_one_option(p, args, index);
                    if new_index > index {
                        index = new_index - 1;  // -1 Because it will be incremented at the bottom of the loop.
                        handled = true;
                        break;
                    } else if new_index < index {
                        log_error("Plugin % decreased argument index. That is illegal!\n", plugin_names[plugin_index]);
                        got_error = true;
                        break;
                    }
                    }

                    if handled continue;

                    log_error("Unknown argument '%'.\nExiting.\n", it);
                    got_error = true;
                    break;
                }

                continue;
        }
    }

    if got_error {
        exit(1);
    }

    if do_check { // @Copypasta, just to make the plugin name arrays come out the same. This is getting silly!
        if check_bindings array_add(*plugin_names2, "Check");
        else              array_add(*plugin_names2, "Check(CHECK_BINDINGS=false)");
    }

    plugins_match := true;
    if plugin_names.count != plugin_names2.count  plugins_match = false;
    else {
        for plugin_names if it != plugin_names2[it_index] plugins_match = false;
    }

    if !plugins_match {
        log_error("Plugins in pass 1 and pass 2 do not match, meaning that -plug was used as an argument to another option. This is an error.\n");
        exit(1);
    }

    old_wd := get_working_directory();

    if printed_help {
        log("\n\n");

        for plugins {
            name := plugin_names[it_index];

            if it.log_help {
                log("---- Help for plugin '%': ----\n\n", name);
                it.log_help(it);
                log("\n");
            } else {
                log("---- Plugin '%' provides no help.\n", name);
            }
        }

        exit(0);
    }

    if modules_paths {
        prefix := "";

        array_add(*modules_paths, ..options.import_path);  // Put these behind whatever the user specified.
        options.import_path = modules_paths;
    }

    options.compile_time_command_line = user_arguments;

    set_build_options(options, w);

    for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

    // As the compiler builds the target program, we can listen in on messages
    // that report the status of the program. In later examples we can use
    // these messages to do sophisticated things, but for now, we'll just
    // use them to report on the status of compilation.

    // To tell the compiler to give us messages, we need to call compiler_begin_intercept
    // before we add any code to the target workspace.
    compiler_begin_intercept(w, intercept_flags);

    if enable_rhi_validation {
        add_build_string("RHI_VALIDATION :: true;", w);
    } else {
        add_build_string("RHI_VALIDATION :: false;", w);
    }
    if enable_vulkan_debug {
        add_build_string("VULKAN_DEBUG :: true;", w);
    }
    else {
        add_build_string("VULKAN_DEBUG :: false;", w);
    }

    if verbose {
        print("Plugins:     %\n", plugins);
    }

    for plugins      if it.add_source it.add_source(it);

    // Add the programs main file
    add_build_file("source/main.jai", w);

    // Call message_loop(), which is a routine of ours below that will receive the messages.
    message_loop(w);

    // When we're done, message_loop will return.
    // We call compiler_end_intercept to tell the compiler we are done.
    compiler_end_intercept(w);

    for plugins if it.finish   it.finish  (it);
    for plugins if it.shutdown it.shutdown(it);

    copy_module_libraries_to_target(options);

    // compile shaders in the build step
    if enable_shader_comp {
        shader_dir := "assets/shaders";
        if !compile_shaders(shader_dir, debug_symbols=enable_vulkan_debug) {
            compiler_set_workspace_status(.FAILED);
            exit(1);
        }
    }

    {
        // None of the code in this file is intended to end up in an executable
        // of any kind. So, we tell the compiler not to make an executable for us:

        set_build_options_dc(.{do_output=false, write_added_strings=false});
    }
}

#run,stallable build(); // If plugins have assertions, they may stall.

//
// message_loop() runs the event loop that reads the messages.
// You can do whatever you want with those messages. The goal
// of this example is just to show the different kinds of messages,
// so we don't do anything crazy yet. But you can do some things
// that are crazy.
//
message_loop :: (w: Workspace) {
    while true {
        // We ask the compiler for the next message. If one is not available,
        // we will wait until it becomes available.
        message := compiler_wait_for_message();
        // Pass the message to all plugins.
        for plugins if it.message it.message(it, message);

        if message.kind == .COMPLETE break;
    
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked) message;
                for tc : typechecked.procedure_headers {
                    header := tc.expression;
                    if has_note(header, "UnitTest") {
                        array_add(*unit_test_functions, header);
                    }
                    if has_note(header, "RunWhenReady") {
                        array_add(*procedures_to_run, header);
                    }
                    if has_note_substr(header, "System") {
                        array_add(*system_functions, header);
                    }
                }
                
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                    if !has_run_procedures {
                        for procedures_to_run {
                            s := tprint("#run %();", it.name);
                            add_build_string(s, message.workspace);
                        }
                        has_run_procedures = true;
                    }

                    if !generated_unit_test_actions {
                        generate_unit_test_actions(message.workspace);
                        generated_unit_test_actions = true;
                    }
                    if !generated_system_functions {
                        generate_system_functions(message.workspace);
                        generated_system_functions = true;
                    }
                }
            }
    }
}

copy_module_libraries_to_target :: (target_options: Build_Options) {
    dir_list :: (path: string, recursive := false) -> [] string #must {
        dirs: [..] string;

        visitor :: (info: *File_Visit_Info, user_data: *[..] string) {
            array_add(user_data, copy_string(info.full_name));
        }

        visit_files(path, recursive, *dirs, visitor, visit_files=false, visit_directories=true);
        return dirs;
    }

    push_allocator(temp);

    module_directories := dir_list("modules", recursive=false);
    for module : module_directories {
        os_names := string.["win", "linux", "mac"];
        
        os_name := "win";
        module_lib_dir_name := tprint("%/%", module, os_name);
        if is_directory(module_lib_dir_name) {

            module_binary_list := file_list(module_lib_dir_name);
            for binary : module_binary_list {
                if ends_with(binary, ".dll") {
                    copy_file(binary, tprint("%/%", target_options.output_path, path_filename(binary)));
                }
            }
        }
    }
}

has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
    for header.notes  if it.text == note  return true;
    return false;
}

has_note_substr :: (header: *Code_Procedure_Header, note_substr: string) -> bool {
    for header.notes  if contains(it.text, note_substr)  return true;
    return false;
}

UNIT_TEST_INSERT :: #string DONE
    array_add(*g_unit_tests, .{"%1", %2});
DONE

generate_unit_test_actions :: (w: Workspace) {
    builder: String_Builder;
    defer free_buffers(*builder);

    print_to_builder(*builder, "register_unit_tests :: () {\n");
    for unit_test_functions {
        print_to_builder(*builder, UNIT_TEST_INSERT, it.name, it.name);
    }
    print_to_builder(*builder, "}\n");

    build_string := builder_to_string(*builder);
    defer free(build_string);

    add_build_string(build_string, w);
}


sbprint :: print_to_builder;
        
generate_system_functions :: (w: Workspace) {
    sb: String_Builder;
    defer free_buffers(*sb);

    parse_system_phase :: (str: string) -> bool, string {
        found, left, right := split_from_left(str, #char "(");
        assert(found);
        if left != "System" {
            return false, "";
        }

        // remove the closing parenthesis and return the view:
        right.count -= 1;
        return true, right;
    }

    parse_read_types :: (str: string) -> bool, string {
        found, left, right := split_from_left(str, #char "(");
        assert(found);
        if left != "Read" {
            return false, "";
        }
        // remove the closing parenthesis before splitting
        right.count -= 1;
        return true, right;
    }
    parse_write_types :: (str: string) -> bool, string {
        found, left, right := split_from_left(str, #char "(");
        assert(found);
        if left != "Write" {
            return false, "";
        }
        // remove the closing parenthesis before splitting
        right.count -= 1;
        return true, right;
    }

    // shuffle the system functions to try to surface bugs that depend on specific system ordering:
    shuffle(system_functions);

    sbprint(*sb, "ALL_SYSTEMS := System_Def.[\n");
    for system_functions {
        // need at least three notes: @System(Phase); @Read(..), @Write(..)
        assert(it.notes.count >= 3);

        phase_valid, phase := parse_system_phase(it.notes[0].text);
        assert(phase_valid, "System phase note is not in the correct syntax! (%, %)", it.name, it_index);

        write_valid, write := parse_write_types(it.notes[1].text);
        assert(write_valid, "System write note is not in the correct syntax! (%, %) (\"%\")", it.name, it_index, it.notes[1].text);

        read_valid, read := parse_read_types(it.notes[2].text);
        assert(read_valid, "System read note is not in the correct syntax! (%, %) (\"%\")", it.name, it_index, it.notes[2].text);


        sbprint(*sb, "\t.{func = %1, debug_name = \"%2\", phase = .%3, component_reads = #run component_type_ids(.[%4]), component_writes = #run component_type_ids(.[%5])}, \n", it.name, it.name, phase, read, write);
    }
    sbprint(*sb, "];");

    add_build_string(builder_to_string(*sb), w);
}

unit_test_functions: [..] *Code_Procedure_Header;
generated_unit_test_actions := false;

procedures_to_run: [..] *Code_Procedure_Header;
has_run_procedures := false;

system_functions: [..] *Code_Procedure_Header;
generated_system_functions := false;


is_absolute_path :: (path: string) -> bool { // This routine is probably not as correct as we'd like. We'd like to put in a better one! But maybe we will stop doing the cwd thing, or do it differently; hard to say.
    if !path return false;

    if path[0] == #char "/" return true;   // Backslashes have not been converted to forward slashes by this point.
    if path[0] == #char "\\" return true;  // Backslashes have not been converted to forward slashes by this point.
    if (path.count > 2) && (path[1] == #char ":") && (OS == .WINDOWS) return true;  // Drive letter stuff. Probably incomplete.

    if path.count >= 3 {
        // @Robustness: Check for a drive letter in character 0?  Anything else?
        if path[1] == #char ":" return true;
    }

    return false;
}

shuffle :: (array: [] $T) {
    Random :: #import "Random";
    
    if array.count < 2 return;

    for i: 0..array.count-1 {
        j := Random.random_get() % cast(u64)(array.count-1);
        Swap(*array[i], *array[j]);
    }
}

#import "Basic";
#import "File";
#import "Compiler";
#import "File_Utilities";
#import "Metaprogram_Plugins";

#load "source/rendering/shader_compilation.jai";


verbose  := false;
plugins: [..] *Metaprogram_Plugin;


HELP_STRING :: #string DONE
Available Command-Line Arguments:

-rhivalidation   Enables RHI validation layers if available. Mildly impacts performance
-vkdebug         Enables vulkan gpu debug callbacks. Severely impacts performance.
-compileshaders  Enables shader recompilation during executable build.
-debugger        If there is a crash in compile-time execution, drop into the interactive debugger.
-debug_for       Enable debugging of for_expansion macros. (Otherwise the debugger will never step into them to make stepping through for loops more convenient.)
-import_dir arg  Add this directory to the list of directories searched by #import. Can be
                     used multiple times.
-llvm            Use the LLVM backend by default (unless overridden by a metaprogram).
                     The LLVM backend is the default normally, so this isn't too useful.
-msvc_format     Use Visual Studio's message format for error messages.
-natvis          Use natvis compatible type names in debug info (array<T> instead of [] T, etc).
-no_backtrace_on_crash    Do not catch OS-level exceptions and print a stack trace when your program crashes.
                     Causes less code to be imported on startup. Depending on your OS (for example, on Windows),
                     crashes may look like silent exits.
-no_color        Disable ANSI terminal coloring in output messages.
-no_dce          Turn off dead code elimination. This is a temporary option,
                     provided because dead code elimination is a new and potentially
                     unstable feature. This will eventually be removed; the preferred way
                     to turn off dead code elimination is via Build_Options.
-no_split        Disable split modules when compiling with the LLVM backend.
-no_check        Do not import modules/Check and run it on the code. The result will be that you won't get
                     augmented error checking for stuff like print() calls. Use this if you want to substitute
                     your own error checking plugin, or for higher speeds in builds known to be good.
-no_check_bindings Disable checking of module bindings when running modules/Check. If modules/Check is not run
                     due to -no_check, this does nothing.
-plug name       Import module 'name' into the metaprogram and use it as a plugin.
-quiet           Run the compiler in quiet mode (not outputting unnecessary text).
-release         Build a release build, i.e., tell the default metaprogram to disable stack traces and enable optimizations.
-profile         Build a profiling build. Enables optimizations and instruments function calls.
-verbose         Output some extra information about what this metaprogram is doing.
-very_debug      Build a very_debug build, i.e. add more debugging facilities than usual, which will cause it to run slower but catch more problems.
-                Every argument after - is ignored by the compiler itself,
                     and is passed to the user-level metaprogram for its own use.

Any argument not starting with a -, and before a - by itself, is the name of a file to compile.

Example:    jai -x64 program.jai - info for -the compile_time execution

There are also a few very tweaky compiler-front-end options that almost nobody
will ever care about. To see these, do:

            jai -- help
DONE
