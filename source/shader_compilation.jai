// This is not currently loaded by the Render module but is instead a utility file
// that can be separately loaded by metaprograms to build shaders

compile_shaders :: (base_directory: string, debug_symbols := false) -> bool {
    source_dir := tprint("%/source", base_directory);
    output_dir := tprint("%/compiled", base_directory);

    #if OS == .WINDOWS {
        shader_compiler := "utils/win/glslc.exe";
    } else #if OS == .LINUX {
        shader_compiler := "utils/linux/glslc";
    } else #if OS == .MACOS {
        shader_compiler := "utils/macos/glslc";
    } else {
        #assert false, "Vulkan shader compilation is not supported in this platform";
    }
    assert(file_exists(shader_compiler), "%", shader_compiler);

    if file_exists(output_dir) delete_directory(output_dir);
    make_directory_if_it_does_not_exist(output_dir, recursive=true);

    for file_list(source_dir) {
        if ends_with(it, ".vert") || ends_with(it, ".frag") {
            flags := ifx debug_symbols then "-g" else "";
            if !compile_shader(shader_compiler, it, flags, output_dir) {
                return false;
            }
        }
    }

    log("Shader compilation succeeded");

    return true;
}

compile_shader :: (shader_compiler: string, shader_path: string, flags: string, output_directory: string) -> bool {
    filename := path_filename(shader_path);

    output_path := tprint("%/%.spv", output_directory, filename);
    compiler_command := string.[shader_compiler, shader_path, "-o", output_path, flags];
    log("Compiling % to % (%)", filename, output_path, get_quoted_command_string(compiler_command));
    result := run_command(..compiler_command);
    if result.exit_code != 0 {
        return false;
    }

    return true;
}

#import "Basic";
#import "File";
#import "File_Utilities";
#import "Process";
#import "String";
