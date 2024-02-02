build :: () {
    // Create a workspace for the target program.
    w := compiler_create_workspace("Sapped");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    // Set the executable name.
    target_options := get_build_options(w);
    target_options.output_executable_name = "sapped";
    target_options.output_path = "bin/";

    set_build_options(target_options, w);

    // compiler_begin_intercept causes us to get messages from this workspace.
    // For this particular program, we are only looking for procedures that have
    // notes attached. So our compiler_begin_intercept has an optional flag that says,
    // don't bother to tell us about anything that doesn't have notes. This means
    // we see many fewer messages, so our metaprogram will go faster.
    compiler_begin_intercept(w, .SKIP_EXPRESSIONS_WITHOUT_NOTES);

    add_build_file(tprint("%source/main.jai", #filepath), w);  // @Cleanup: Fix this to not require #filepath.

    message_loop();

    compiler_end_intercept(w);

    print("\nDone!\n\n");

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

        if message.kind == {
          case .TYPECHECKED;
            
          case .PHASE;
            phase := cast(*Message_Phase) message;
            if phase.phase == .TYPECHECKED_ALL_WE_CAN {
            }
            
          case .COMPLETE;
            break;
        }
    }
}

#scope_file

has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
    for header.notes  if it.text == note  return true;
    return false;
}

#import "Basic";
#import "Compiler";
#import "String";