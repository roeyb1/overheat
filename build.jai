build :: () {
    // Create a workspace for the target program.
    w := compiler_create_workspace("Overheat");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    plugin_names: [..] string;
    // parse the compile time command line arguments:
    {
        args := get_build_options().compile_time_command_line;

        index := 0;
        while index < args.count {
            defer index += 1;

            it := args[index];
            if it == {
                case "-profile";
                    array_add(*plugin_names, "tracy");
                case;
            }
        }
    }

    // Set the executable name.
    target_options := get_build_options(w);
    target_options.output_executable_name = "overheat";
    target_options.output_path = "bin/";

    // bin folder should contain per-os subdirs:
    if target_options.os_target == {
        case .WINDOWS;
            target_options.output_path = "bin/win";
        case .LINUX;
            target_options.output_path = "bin/linux";
        case .MACOS;
            target_options.output_path = "bin/macos";
    }

    make_directory_if_it_does_not_exist(target_options.output_path, recursive=true);

    init_plugins(plugin_names, *plugins, w);

    set_build_options(target_options, w);

    intercept_flags: Intercept_Flags;
    for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);


    // compiler_begin_intercept causes us to get messages from this workspace.
    // For this particular program, we are only looking for procedures that have
    // notes attached. So our compiler_begin_intercept has an optional flag that says,
    // don't bother to tell us about anything that doesn't have notes. This means
    // we see many fewer messages, so our metaprogram will go faster.
    compiler_begin_intercept(w, intercept_flags);

    for plugins if it.add_source it.add_source(it);

    add_build_file(tprint("%source/main.jai", #filepath), w);  // @Cleanup: Fix this to not require #filepath.

    message_loop();

    compiler_end_intercept(w);


    for plugins if it.finish   it.finish  (it);
    for plugins if it.shutdown it.shutdown(it);

    print("\nDone!\n\n");

    copy_module_libraries_to_target(target_options);

    shader_dir := "assets/shaders";
    if !compile_shaders(shader_dir, debug_symbols=true) {
        compiler_set_workspace_status(.FAILED);
        return;
    }

    // This metaprogram should not generate any output executable:
    set_build_options_dc(.{do_output=false});
}

#run build();

//
// In our message_loop, we first look for any procedures that are marked @RunWhenReady.
// We put these into an array. Later on during the build phase, we generate a #run for
// every procedure in that array.
//
// For an example this simple, we don't actually need to do this in two phases; we could
// just add the #run right when we see the procedure. But the idea here is that maybe
// there is some other processing you want to do, such that it makes sense to
// wait until after that processing has been done, and to handle all the code generation
// at the same time (maybe you want to put these procedures into an array, and so forth).
//
message_loop :: () {
    while true {
        message := compiler_wait_for_message();
        for plugins if it.message it.message(it, message);

        if message.kind == {
          case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked) message;
            for tc : typechecked.procedure_headers {
                header := tc.expression;
                if has_note(header, "RegisterInputAction") {
                    array_add(*key_mapped_actions, header);
                }
                if has_note(header, "UnitTest") {
                    array_add(*unit_test_functions, header);
                }
                if has_note(header, "RunWhenReady") {
                    array_add(*procedures_to_run, header);
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

                if !generated_keymap_actions {
                    generate_keymap_actions(message.workspace);
                    generated_keymap_actions = true;
                }

                if !generated_unit_test_actions {
                    generate_unit_test_actions(message.workspace);
                    generated_unit_test_actions = true;
                }
            }
            
          case .COMPLETE;
            break;
        }
    }
}

#scope_file

/**
 * Copy data from the platform folders of modules next to the executable so they can be picked up by dlopens.
 * We could instead leverage parsing of libraries to detect the files as is done here: https://gist.github.com/uucidl/c5b9505a3b3a6cced5dc5a34080df6c3
 */

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

    // this is a kind of shitty way to do this, ideally we would just look into the /win/ directories directly
    module_directories := dir_list("modules", recursive=false);
    for module : module_directories {
        os_names := string.["win", "linux", "mac"];
        
        for os_name : os_names {
            module_lib_dir_name := tprint("%/%", module, os_name);
            if is_directory(module_lib_dir_name) {
                copy_directory(module_lib_dir_name, target_options.output_path);
            }
        }

    }
}

has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
    for header.notes  if it.text == note  return true;
    return false;
}

KEYMAP_ACTION_INSERT :: #string DONE
    array_add(*key_map.actions, .{action_name = "%1", proc = %1});
DONE

generate_keymap_actions :: (w: Workspace) {
    builder: String_Builder;
    defer free_buffers(*builder);

    print_to_builder(*builder, "register_all_input_actions :: (key_map: *Keymap) {\n");
    for mapped_action : key_mapped_actions {
        assert(mapped_action.arguments.count == 1, 
            "Mapped input action '%' doesn't have any parameters! Expected signature: (key_state: Key_Current_State) -> ()", mapped_action.name);

        assert(mapped_action.arguments[0].type_inst.result.type == .ENUM, 
            "Mapped input action '%' has incorrect parameter types! Expected signature: (key_state: Key_Current_State) -> ()", mapped_action.name);

        enum_type := cast(*Type_Info_Enum) mapped_action.arguments[0].type_inst.result;

        assert(enum_type.name == "Key_Current_State", 
            "Mapped input action '%' has incorrect parameter types! Expected signature: (key_state: Key_Current_State) -> ()", mapped_action.name);

        assert(mapped_action.returns.count == 0, 
            "Mapped input action '%' has a return type! Expected signature: (key_state: Key_Current_State) -> ()", mapped_action.name);

        print_to_builder(*builder, KEYMAP_ACTION_INSERT, mapped_action.name);
    }
    print_to_builder(*builder, "}\n");

    build_string := builder_to_string(*builder);
    add_build_string(build_string, w);
}

UNIT_TEST_INSERT :: #string DONE
    array_add(*g_unit_test_functions, %1);
DONE
generate_unit_test_actions :: (w: Workspace) {
    builder: String_Builder;
    defer free_buffers(*builder);

    print_to_builder(*builder, "register_unit_tests :: () {\n");
    for unit_test_functions {
        print_to_builder(*builder, UNIT_TEST_INSERT, it.name);
    }
    print_to_builder(*builder, "}\n");

    build_string := builder_to_string(*builder);
    add_build_string(build_string, w);
}

plugins: [..] *Metaprogram_Plugin;

key_mapped_actions: [..] *Code_Procedure_Header;
generated_keymap_actions := false;


unit_test_functions: [..] *Code_Procedure_Header;
generated_unit_test_actions := false;

procedures_to_run: [..] *Code_Procedure_Header;
has_run_procedures := false;

#import "Basic";
#import "Compiler";
#import "String";
#import "File_Utilities";
#import "Metaprogram_Plugins";

#load "source/shader_compilation.jai";