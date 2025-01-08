COMPILE_LIBRARY :: true;

VMA_PATH :: "source/vk_mem_alloc.cpp";

#run {
    set_build_options_dc(.{do_output = false});

    options := get_build_options();
    target_android := array_find(options.compile_time_command_line, "android");

    os := OS;
    cpu := CPU;
    if target_android {
        os = .ANDROID, binary_path, binary_path));
        cpu = .ARM64;
    }

    success: bool;
    #if COMPILE_LIBRARY {
        success = compile_vma(os, cpu);
        if !success {
            compiler_set_workspace_status(.FAILED);
            return;
        }
    }

    if os == .ANDROID {
        log("Skipping bindings generator because we can’t cross-generate bindings without a static library atm.");
    } else {
        success = generate_bindings(os, cpu);
        if !success compiler_set_workspace_status(.FAILED);
    }
};

// Note: this hasn't been tested on Linux
compile_vma :: (os: Operating_System_Tag, cpu: CPU_Tag) -> bool {
    log("Compiling VMA…");
    if os == {
        case .WINDOWS;
            make_directory_if_it_does_not_exist("windows");
            return build_cpp_dynamic_lib("win/libvma", VMA_PATH,
                extra = .["/I", VULKAN_PATHS.include, "/DVMA_IMPLEMENTATION", "/DVK_ERROR_UNKNOWN=((VkResult)-13)", "/DVMA_CALL_PRE=__declspec(dllexport)", "/std:c++14"],
                library_files = .[VULKAN_PATHS.import_library]
            );

        case .LINUX;
            make_directory_if_it_does_not_exist("linux");
            return build_cpp_dynamic_lib("linux/libvma", VMA_PATH, extra = .["-I", VULKAN_PATHS.include, "-DVMA_IMPLEMENTATION", "-x", "c++", "-std=c++17", "-lstdc++", "-fno-exceptions", "-fno-rtti", "-lvulkan"]);

        case .ANDROID;
            make_directory_if_it_does_not_exist("android");
            ndk := get_ndk_paths();
            target_triple := get_android_target_triple(cpu);
            return build_cpp_dynamic_lib("android/libvma", VMA_PATH, target = .LINUX, extra = .["-I", VULKAN_PATHS.include, "-DVMA_IMPLEMENTATION", "-DVK_ERROR_UNKNOWN=((VkResult)-13)", "-x", "c++", "-std=c++17", "--sysroot", ndk.sysroot, "-L", tprint("%/usr/lib/%/%", ndk.sysroot, target_triple, ANDROID_SDK_LEVEL), "-target", target_triple, "-nostartfiles", "-fno-exceptions", "-fno-rtti", "-static-libstdc++"]);

        case .MACOS;
            make_directory_if_it_does_not_exist("macos");
            success := build_cpp_dynamic_lib("macos/libvma", VMA_PATH, extra = .["-I", VULKAN_PATHS.include, "-DVMA_IMPLEMENTATION", "-DVK_ERROR_UNKNOWN=((VkResult)-13)", "-x", "c++", "-std=c++17", "-lc++", "-lvulkan.1", "-fno-exceptions", "-fno-rtti"]);
            if !success return false;

            // Update the Vulkan rpath to point to the system library location
            rpath_result := run_command("install_name_tool", "-change", "@rpath/libvulkan.1.dylib", "/usr/local/lib/libvulkan.1.dylib", "macos/libvma.dylib");
            if rpath_result.exit_code != 0 {
                log_error("Failed to change Vulkan rpath");
                return false;
            }
            return true;

        case;
            assert(false);
            return false;
    }
}

generate_bindings :: (target_os: Operating_System_Tag, target_cpu: CPU_Tag) -> bool {
    output_filename := "bindings.jai";
    options: Generate_Bindings_Options;
    options.os = target_os;
    options.cpu = target_cpu;

    {
        using options;

        if target_os == {
            case .WINDOWS;
                array_add(*libpaths, "windows");
            case .LINUX;
                array_add(*libpaths, "linux");
            case .ANDROID;
                array_add(*libpaths, "android");
            case .MACOS;
                array_add(*libpaths, "macos");
            case;
                assert(false, "Vulkan Memory Allocator is not supported in this platform");
        }

        array_add(*libnames, "libvma");

        array_add(*extra_clang_arguments, "-x", "c");
        array_add(*source_files, VMA_PATH);

        array_add(*system_include_paths, ..get_default_system_include_paths());
        array_add(*system_include_paths, VULKAN_PATHS.include);

        alias_original_enum_names = false;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;

        generate_library_declarations = false;
        will_print_bindings = () {
            // Change the library name to be the same on all platforms
            // so that we don't have to generate identical bindings for every platform just because the library name is different.
            context.generator.libraries[0].name = "libvma";
        };
        footer = VMA_FOOTER;
    }

    return generate_bindings(options, output_filename);
}

VMA_FOOTER :: #string END
#if OS == .WINDOWS {
    libvma :: #library "win/libvma";
} else #if OS == .LINUX {
    libvma :: #library "linux/libvma";
} else #if OS == .MACOS {
    libvma :: #library "macos/libvma";
} else #if OS == .ANDROID {
    libvma :: #library "android/libvma";
} else {
    #assert false "Unsupported OS";
}
END

#import "Toolchains/Android";
#import "Basic";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Process";
#import "String";
#import,file "../Vulkan_Paths.jai";
