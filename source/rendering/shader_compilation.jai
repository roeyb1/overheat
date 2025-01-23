// This is not currently loaded by the Render module but is instead a utility file
// that can be separately loaded by metaprograms to build shaders

compile_shaders :: (base_directory: string, debug_symbols := false) -> bool {
    source_dir := tprint("%/source", base_directory);
    output_dir := tprint("%/compiled", base_directory);

    #if OS == .WINDOWS {
        shader_compiler := "utils/win/dxc.exe";
    } else #if OS == .LINUX {
        shader_compiler := "utils/linux/dxc";
    } else #if OS == .MACOS {
        shader_compiler := "dxc";
    } else {
        assert(false, "Vulkan shader compilation is not supported in this platform");
    }
    assert(file_exists(shader_compiler), "%", shader_compiler);

    if file_exists(output_dir) delete_directory(output_dir);
    make_directory_if_it_does_not_exist(output_dir, recursive=true);

    success := true;
    for file_list(source_dir) {
        if ends_with(it, "_vs.hlsl") || ends_with(it, "_ps.hlsl") || ends_with(it, "_cs.hlsl") {
            success &= compile_shader(shader_compiler, it, output_dir, debug_symbols);
        }
    }

    if success {
        log("Shader compilation succeeded!");
    } else {
        log_error("Shader compilation failed! Check the log for details");
    }

    return true;
}

compile_shader :: (shader_compiler: string, shader_path: string, output_directory: string, debug_symbols: bool) -> bool {
    filename := path_filename(shader_path);

    shader_type: string;
    if ends_with(shader_path, "_vs.hlsl") {
        shader_type = "-T vs_6_0";
    } else if ends_with(shader_path, "_ps.hlsl") {
        shader_type = "-T ps_6_0";
    } else if ends_with(shader_path, "_cs.hlsl") {
        shader_type = "-T cs_6_0";
    }

    if shader_type.count == 0 {
        log_error("Failed to compile shader %. Unable to detect shader type. Ensure the shader ends with the correct suffix!", shader_path);
        return false;
    }

    output_path := tprint("%/%.spv", output_directory, path_strip_extension(filename));
    compiler_command := string.[
        shader_compiler,
        "-D VULKAN=1",
        "-spirv",
        "-fspv-target-env=vulkan1.2",
        ifx shader_type[3] == #char "v" then "-fvk-invert-y" else "",
        shader_type,
        "-E main",
        shader_path,
        "-Fo",
        output_path,
    ];

    log("Compiling % to % (%)", filename, output_path, get_quoted_command_string(compiler_command));
    result := run_command(..compiler_command);
    if result.exit_code != 0 {
        return false;
    }

    return true;
}

#import "File";
#import "File_Utilities";
#import "Process";
#import "String";
