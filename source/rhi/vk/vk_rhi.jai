#scope_export

DEBUG_VULKAN :: true;

// Instance data:
instance: VkInstance;
surface: VkSurfaceKHR;

#if DEBUG_VULKAN {
    debug_callback_handle: VkDebugReportCallbackEXT;
}


init_rhi :: () {
    result: VkResult = .ERROR_INITIALIZATION_FAILED;

    app_info: VkApplicationInfo;
    app_info.sType = .APPLICATION_INFO;
    app_info.pApplicationName = "Overheat";
    app_info.applicationVersion = VK_MAKE_VERSION(0, 1, 0);
    app_info.pEngineName = "Overheat Engine";
    app_info.engineVersion = VK_MAKE_VERSION(0, 1, 0);
    app_info.apiVersion = VK_API_VERSION_1_2;

    create_info: VkInstanceCreateInfo;
    create_info.sType = .INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = *app_info;

    instance_extensions: [..] *u8;
    instance_extensions.allocator = temp;
    #if DEBUG_VULKAN {
        array_add(*instance_extensions, VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data);
        array_add(*instance_extensions, VK_EXT_DEBUG_UTILS_EXTENSION_NAME.data);
    }

    #if OS == .WINDOWS {
        array_add(*instance_extensions, VK_KHR_SURFACE_EXTENSION_NAME.data);
        array_add(*instance_extensions, VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data);
    } else {
        #assert(false); // #todo: surface extension for linux/mac?
    }

    create_info.enabledExtensionCount = xx instance_extensions.count;
    create_info.ppEnabledExtensionNames = instance_extensions.data;

    #if DEBUG_VULKAN {
        debug_create_info := create_info;
        debug_create_info.enabledLayerCount = 1;
        debug_create_info.ppEnabledLayerNames = (*u8).["VK_LAYER_KHRONOS_validation"].data;

        enabled_validation_features := VkValidationFeatureEnableEXT.[
            .GPU_ASSISTED_EXT,
            .GPU_ASSISTED_RESERVE_BINDING_SLOT_EXT,
        ];

        validation_features := VkValidationFeaturesEXT.{
            enabledValidationFeatureCount = enabled_validation_features.count,
            pEnabledValidationFeatures  = enabled_validation_features.data,
        };

        debug_messenger_create_info := VkDebugUtilsMessengerCreateInfoEXT.{
            messageSeverity = .VERBOSE_BIT_EXT | .INFO_BIT_EXT | .WARNING_BIT_EXT | .ERROR_BIT_EXT,
            messageType = .GENERAL_BIT_EXT | .VALIDATION_BIT_EXT | .PERFORMANCE_BIT_EXT,
            pfnUserCallback = debug_callback,
            pUserData = null,
            pNext = *validation_features,
        };

        debug_create_info.pNext = *debug_messenger_create_info;

        
        result = vkCreateInstance(*debug_create_info, null, *instance);
        if result == .SUCCESS {
            vkCreateDebugReportCallbackEXT: PFN_vkCreateDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance, "vkCreateDebugReportCallbackEXT");

            if vkCreateDebugReportCallbackEXT {
                debug_callback_create_info: VkDebugReportCallbackCreateInfoEXT;
                debug_callback_create_info.flags |= .ERROR_BIT_EXT;
                debug_callback_create_info.flags |= .WARNING_BIT_EXT;
                debug_callback_create_info.pfnCallback = validation_callback;

                vkCreateDebugReportCallbackEXT(instance, *debug_callback_create_info, null, *debug_callback_handle);
            }
        }

    }

    if result != .SUCCESS {
        result = vkCreateInstance(*create_info, null,  *instance);
    }

    assert(result == .SUCCESS);

    log("Initialized Vulkan instance");
}

destroy_rhi :: () {
    #if DEBUG_VULKAN {
        vkDestroyDebugReportCallbackEXT: PFN_vkDestroyDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance, "vkDestroyDebugReportCallbackEXT");
        if vkDestroyDebugReportCallbackEXT != null {
            vkDestroyDebugReportCallbackEXT(instance, debug_callback_handle, null);
        }
    }

    vkDestroyInstance(instance, null);
}

init_surface :: () {
    #if OS == .WINDOWS {
        window_handle := game_window;
        surface_create_info: VkWin32SurfaceCreateInfoKHR;
        surface_create_info.sType = .WIN32_SURFACE_CREATE_INFO_KHR;
        surface_create_info.hinstance = GetModuleHandleW(null);
        surface_create_info.hwnd = window_handle;
        result := vkCreateWin32SurfaceKHR(instance, *surface_create_info, null, *surface);
        assert(result == .SUCCESS);

        log("Initialized Win32 Surface");
    } else {
        #assert(false);
    }
}

destroy_surface :: () {
    vkDestroySurfaceKHR(instance, surface, null);
}


#load "vk_device.jai";
#load "vk_debug.jai";
#load "vk_resources.jai";
#load "vk_swapchain.jai";
#load "vk_descriptor_set.jai";
#load "vk_cmd_list.jai";

#import "Vulkan";