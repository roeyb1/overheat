// These are paths for the Vulkan headers and libraries used by the Vulkan module distributed with the compiler.
// This is useful for generating bindings for libraries that depend on Vulkan.

Vulkan_Paths :: struct {
    include: string;

    import_library: string;
    shared_library: string;
}

VULKAN_PATHS :: #run,stallable -> Vulkan_Paths {

    compiler_base_path := compiler_get_base_path();

    vulkan_base_path := tprint("%/modules/Vulkan", compiler_base_path);
    vulkan_source_path := tprint("%/source", vulkan_base_path);

    #if OS == .WINDOWS {
        import_library := tprint("%/win/vulkan-1.lib", vulkan_base_path);
        shared_library := tprint("%/win/vulkan-1.dll", vulkan_base_path);
        return .{include = vulkan_source_path, import_library = import_library, shared_library = shared_library};
    } else {
        return .{include = vulkan_source_path};
    }
};

#import "Basic";
#import "Compiler";
#import "File_Utilities";
#import "System";
