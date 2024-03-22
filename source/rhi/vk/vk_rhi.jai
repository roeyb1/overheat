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

rhi_translate :: (flags: RHIShaderStageFlags) -> VkShaderStageFlags {
    result: VkShaderStageFlags = 0;

    if test_flag_bit(flags, RHIShaderStageFlags.VERTEX_BIT) {
        result |= .VERTEX_BIT;
    }
    if test_flag_bit(flags, RHIShaderStageFlags.HULL_BIT) {
        result |= .TESSELLATION_CONTROL_BIT;
    }
    if test_flag_bit(flags, RHIShaderStageFlags.DOMAIN_BIT) {
        result |= .TESSELLATION_EVALUATION_BIT;
    }
    if test_flag_bit(flags, RHIShaderStageFlags.GEOMETRY_BIT) {
        result |= .GEOMETRY_BIT;
    }
    if test_flag_bit(flags, RHIShaderStageFlags.PIXEL_BIT) {
        result |= .FRAGMENT_BIT;
    }
    if test_flag_bit(flags, RHIShaderStageFlags.COMPUTE_BIT) {
        result |= .COMPUTE_BIT;
    }

    return result;
}

rhi_translate :: (flags: RHIPipelineStageFlags) -> VkPipelineStageFlags {
    result: VkPipelineStageFlags = 0;

    if test_flag_bit(flags, RHIPipelineStageFlags.TOP_OF_PIPE_BIT) {
        result |= .TOP_OF_PIPE_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.DRAW_INDIRECT_BIT) {
        result |= .DRAW_INDIRECT_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.VERTEX_INPUT_BIT) {
        result |= .VERTEX_INPUT_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.VERTEX_SHADER_BIT) {
        result |= .VERTEX_SHADER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.HULL_SHADER_BIT) {
        result |= .TESSELLATION_CONTROL_SHADER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.DOMAIN_SHADER_BIT) {
        result |= .TESSELLATION_EVALUATION_SHADER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.GEOMETRY_SHADER_BIT) {
        result |= .GEOMETRY_SHADER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.PIXEL_SHADER_BIT) {
        result |= .FRAGMENT_SHADER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.EARLY_FRAGMENT_TESTS_BIT) {
        result |= .EARLY_FRAGMENT_TESTS_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.LATE_FRAGMENT_TESTS_BIT) {
        result |= .LATE_FRAGMENT_TESTS_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.COLOR_ATTACHMENT_OUTPUT_BIT) {
        result |= .COLOR_ATTACHMENT_OUTPUT_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.COMPUTE_SHADER_BIT) {
        result |= .COMPUTE_SHADER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.TRANSFER_BIT) {
        result |= .TRANSFER_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.BOTTOM_OF_PIPE_BIT) {
        result |= .BOTTOM_OF_PIPE_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.HOST_BIT) {
        result |= .HOST_BIT;
    }
    if test_flag_bit(flags, RHIPipelineStageFlags.CLEAR_BIT) {
        result |= .TRANSFER_BIT;
    }

    return result;
}

rhi_image_aspect_mask :: (format: VkFormat) -> VkImageAspectFlags {
    if format == {
        case .D16_UNORM; #through;
        case .X8_D24_UNORM_PACK32; #through;
        case .D32_SFLOAT;
            return .DEPTH_BIT;
        case .S8_UINT;
            return .STENCIL_BIT;
        case .D16_UNORM_S8_UINT; #through;
        case .D24_UNORM_S8_UINT; #through;
        case .D32_SFLOAT_S8_UINT;
            return .DEPTH_BIT | .STENCIL_BIT;
        case;
            return .COLOR_BIT;
    }
}

rhi_translate :: (format: RHIFormat) -> VkFormat {
    if format == {
        case .UNDEFINED;
            return .UNDEFINED;
        case .R4G4_UNORM_PACK8;
            return .R4G4_UNORM_PACK8;
        case .R4G4B4A4_UNORM_PACK16;
            return .R4G4B4A4_UNORM_PACK16;
        case .B4G4R4A4_UNORM_PACK16;
            return .B4G4R4A4_UNORM_PACK16;
        case .R5G6B5_UNORM_PACK16;
            return .R5G6B5_UNORM_PACK16;
        case .B5G6R5_UNORM_PACK16;
            return .B5G6R5_UNORM_PACK16;
        case .R5G5B5A1_UNORM_PACK16;
            return .R5G5B5A1_UNORM_PACK16;
        case .B5G5R5A1_UNORM_PACK16;
            return .B5G5R5A1_UNORM_PACK16;
        case .A1R5G5B5_UNORM_PACK16;
            return .A1R5G5B5_UNORM_PACK16;
        case .R8_UNORM;
            return .R8_UNORM;
        case .R8_SNORM;
            return .R8_SNORM;
        case .R8_USCALED;
            return .R8_USCALED;
        case .R8_SSCALED;
            return .R8_SSCALED;
        case .R8_UINT;
            return .R8_UINT;
        case .R8_SINT;
            return .R8_SINT;
        case .R8_SRGB;
            return .R8_SRGB;
        case .R8G8_UNORM;
            return .R8G8_UNORM;
        case .R8G8_SNORM;
            return .R8G8_SNORM;
        case .R8G8_USCALED;
            return .R8G8_USCALED;
        case .R8G8_SSCALED;
            return .R8G8_SSCALED;
        case .R8G8_UINT;
            return .R8G8_UINT;
        case .R8G8_SINT;
            return .R8G8_SINT;
        case .R8G8_SRGB;
            return .R8G8_SRGB;
        case .R8G8B8_UNORM;
            return .R8G8B8_UNORM;
        case .R8G8B8_SNORM;
            return .R8G8B8_SNORM;
        case .R8G8B8_USCALED;
            return .R8G8B8_USCALED;
        case .R8G8B8_SSCALED;
            return .R8G8B8_SSCALED;
        case .R8G8B8_UINT;
            return .R8G8B8_UINT;
        case .R8G8B8_SINT;
            return .R8G8B8_SINT;
        case .R8G8B8_SRGB;
            return .R8G8B8_SRGB;
        case .B8G8R8_UNORM;
            return .B8G8R8_UNORM;
        case .B8G8R8_SNORM;
            return .B8G8R8_SNORM;
        case .B8G8R8_USCALED;
            return .B8G8R8_USCALED;
        case .B8G8R8_SSCALED;
            return .B8G8R8_SSCALED;
        case .B8G8R8_UINT;
            return .B8G8R8_UINT;
        case .B8G8R8_SINT;
            return .B8G8R8_SINT;
        case .B8G8R8_SRGB;
            return .B8G8R8_SRGB;
        case .R8G8B8A8_UNORM;
            return .R8G8B8A8_UNORM;
        case .R8G8B8A8_SNORM;
            return .R8G8B8A8_SNORM;
        case .R8G8B8A8_USCALED;
            return .R8G8B8A8_USCALED;
        case .R8G8B8A8_SSCALED;
            return .R8G8B8A8_SSCALED;
        case .R8G8B8A8_UINT;
            return .R8G8B8A8_UINT;
        case .R8G8B8A8_SINT;
            return .R8G8B8A8_SINT;
        case .R8G8B8A8_SRGB;
            return .R8G8B8A8_SRGB;
        case .B8G8R8A8_UNORM;
            return .B8G8R8A8_UNORM;
        case .B8G8R8A8_SNORM;
            return .B8G8R8A8_SNORM;
        case .B8G8R8A8_USCALED;
            return .B8G8R8A8_USCALED;
        case .B8G8R8A8_SSCALED;
            return .B8G8R8A8_SSCALED;
        case .B8G8R8A8_UINT;
            return .B8G8R8A8_UINT;
        case .B8G8R8A8_SINT;
            return .B8G8R8A8_SINT;
        case .B8G8R8A8_SRGB;
            return .B8G8R8A8_SRGB;
        case .A8B8G8R8_UNORM_PACK32;
            return .A8B8G8R8_UNORM_PACK32;
        case .A8B8G8R8_SNORM_PACK32;
            return .A8B8G8R8_SNORM_PACK32;
        case .A8B8G8R8_USCALED_PACK32;
            return .A8B8G8R8_USCALED_PACK32;
        case .A8B8G8R8_SSCALED_PACK32;
            return .A8B8G8R8_SSCALED_PACK32;
        case .A8B8G8R8_UINT_PACK32;
            return .A8B8G8R8_UINT_PACK32;
        case .A8B8G8R8_SINT_PACK32;
            return .A8B8G8R8_SINT_PACK32;
        case .A8B8G8R8_SRGB_PACK32;
            return .A8B8G8R8_SRGB_PACK32;
        case .A2R10G10B10_UNORM_PACK32;
            return .A2R10G10B10_UNORM_PACK32;
        case .A2R10G10B10_SNORM_PACK32;
            return .A2R10G10B10_SNORM_PACK32;
        case .A2R10G10B10_USCALED_PACK32;
            return .A2R10G10B10_USCALED_PACK32;
        case .A2R10G10B10_SSCALED_PACK32;
            return .A2R10G10B10_SSCALED_PACK32;
        case .A2R10G10B10_UINT_PACK32;
            return .A2R10G10B10_UINT_PACK32;
        case .A2R10G10B10_SINT_PACK32;
            return .A2R10G10B10_SINT_PACK32;
        case .A2B10G10R10_UNORM_PACK32;
            return .A2B10G10R10_UNORM_PACK32;
        case .A2B10G10R10_SNORM_PACK32;
            return .A2B10G10R10_SNORM_PACK32;
        case .A2B10G10R10_USCALED_PACK32;
            return .A2B10G10R10_USCALED_PACK32;
        case .A2B10G10R10_SSCALED_PACK32;
            return .A2B10G10R10_SSCALED_PACK32;
        case .A2B10G10R10_UINT_PACK32;
            return .A2B10G10R10_UINT_PACK32;
        case .A2B10G10R10_SINT_PACK32;
            return .A2B10G10R10_SINT_PACK32;
        case .R16_UNORM;
            return .R16_UNORM;
        case .R16_SNORM;
            return .R16_SNORM;
        case .R16_USCALED;
            return .R16_USCALED;
        case .R16_SSCALED;
            return .R16_SSCALED;
        case .R16_UINT;
            return .R16_UINT;
        case .R16_SINT;
            return .R16_SINT;
        case .R16_SFLOAT;
            return .R16_SFLOAT;
        case .R16G16_UNORM;
            return .R16G16_UNORM;
        case .R16G16_SNORM;
            return .R16G16_SNORM;
        case .R16G16_USCALED;
            return .R16G16_USCALED;
        case .R16G16_SSCALED;
            return .R16G16_SSCALED;
        case .R16G16_UINT;
            return .R16G16_UINT;
        case .R16G16_SINT;
            return .R16G16_SINT;
        case .R16G16_SFLOAT;
            return .R16G16_SFLOAT;
        case .R16G16B16_UNORM;
            return .R16G16B16_UNORM;
        case .R16G16B16_SNORM;
            return .R16G16B16_SNORM;
        case .R16G16B16_USCALED;
            return .R16G16B16_USCALED;
        case .R16G16B16_SSCALED;
            return .R16G16B16_SSCALED;
        case .R16G16B16_UINT;
            return .R16G16B16_UINT;
        case .R16G16B16_SINT;
            return .R16G16B16_SINT;
        case .R16G16B16_SFLOAT;
            return .R16G16B16_SFLOAT;
        case .R16G16B16A16_UNORM;
            return .R16G16B16A16_UNORM;
        case .R16G16B16A16_SNORM;
            return .R16G16B16A16_SNORM;
        case .R16G16B16A16_USCALED;
            return .R16G16B16A16_USCALED;
        case .R16G16B16A16_SSCALED;
            return .R16G16B16A16_SSCALED;
        case .R16G16B16A16_UINT;
            return .R16G16B16A16_UINT;
        case .R16G16B16A16_SINT;
            return .R16G16B16A16_SINT;
        case .R16G16B16A16_SFLOAT;
            return .R16G16B16A16_SFLOAT;
        case .R32_UINT;
            return .R32_UINT;
        case .R32_SINT;
            return .R32_SINT;
        case .R32_SFLOAT;
            return .R32_SFLOAT;
        case .R32G32_UINT;
            return .R32G32_UINT;
        case .R32G32_SINT;
            return .R32G32_SINT;
        case .R32G32_SFLOAT;
            return .R32G32_SFLOAT;
        case .R32G32B32_UINT;
            return .R32G32B32_UINT;
        case .R32G32B32_SINT;
            return .R32G32B32_SINT;
        case .R32G32B32_SFLOAT;
            return .R32G32B32_SFLOAT;
        case .R32G32B32A32_UINT;
            return .R32G32B32A32_UINT;
        case .R32G32B32A32_SINT;
            return .R32G32B32A32_SINT;
        case .R32G32B32A32_SFLOAT;
            return .R32G32B32A32_SFLOAT;
        case .R64_UINT;
            return .R64_UINT;
        case .R64_SINT;
            return .R64_SINT;
        case .R64_SFLOAT;
            return .R64_SFLOAT;
        case .R64G64_UINT;
            return .R64G64_UINT;
        case .R64G64_SINT;
            return .R64G64_SINT;
        case .R64G64_SFLOAT;
            return .R64G64_SFLOAT;
        case .R64G64B64_UINT;
            return .R64G64B64_UINT;
        case .R64G64B64_SINT;
            return .R64G64B64_SINT;
        case .R64G64B64_SFLOAT;
            return .R64G64B64_SFLOAT;
        case .R64G64B64A64_UINT;
            return .R64G64B64A64_UINT;
        case .R64G64B64A64_SINT;
            return .R64G64B64A64_SINT;
        case .R64G64B64A64_SFLOAT;
            return .R64G64B64A64_SFLOAT;
        case .B10G11R11_UFLOAT_PACK32;
            return .B10G11R11_UFLOAT_PACK32;
        case .E5B9G9R9_UFLOAT_PACK32;
            return .E5B9G9R9_UFLOAT_PACK32;
        case .D16_UNORM;
            return .D16_UNORM;
        case .X8_D24_UNORM_PACK32;
            return .X8_D24_UNORM_PACK32;
        case .D32_SFLOAT;
            return .D32_SFLOAT;
        case .S8_UINT;
            return .S8_UINT;
        case .D16_UNORM_S8_UINT;
            return .D16_UNORM_S8_UINT;
        case .D24_UNORM_S8_UINT;
            return .D24_UNORM_S8_UINT;
        case .D32_SFLOAT_S8_UINT;
            return .D32_SFLOAT_S8_UINT;
        case .BC1_RGB_UNORM_BLOCK;
            return .BC1_RGB_UNORM_BLOCK;
        case .BC1_RGB_SRGB_BLOCK;
            return .BC1_RGB_SRGB_BLOCK;
        case .BC1_RGBA_UNORM_BLOCK;
            return .BC1_RGBA_UNORM_BLOCK;
        case .BC1_RGBA_SRGB_BLOCK;
            return .BC1_RGBA_SRGB_BLOCK;
        case .BC2_UNORM_BLOCK;
            return .BC2_UNORM_BLOCK;
        case .BC2_SRGB_BLOCK;
            return .BC2_SRGB_BLOCK;
        case .BC3_UNORM_BLOCK;
            return .BC3_UNORM_BLOCK;
        case .BC3_SRGB_BLOCK;
            return .BC3_SRGB_BLOCK;
        case .BC4_UNORM_BLOCK;
           return .BC4_UNORM_BLOCK;
        case .BC4_SNORM_BLOCK;
            return .BC4_SNORM_BLOCK;
        case .BC5_UNORM_BLOCK;
            return .BC5_UNORM_BLOCK;
        case .BC5_SNORM_BLOCK;
            return .BC5_SNORM_BLOCK;
        case .BC6H_UFLOAT_BLOCK;
            return .BC6H_UFLOAT_BLOCK;
        case .BC6H_SFLOAT_BLOCK;
            return .BC6H_SFLOAT_BLOCK;
        case .BC7_UNORM_BLOCK;
            return .BC7_UNORM_BLOCK;
        case .BC7_SRGB_BLOCK;
            return .BC7_SRGB_BLOCK;
        case;
            assert(false);
    }
    return .UNDEFINED;
}

rhi_translate :: (image_type: RHIImageType) -> VkImageType {
    if image_type == {
        case ._1D; return ._1D;
        case ._2D; return ._2D;
        case ._3D; return ._3D;
    }

    assert(false);
    return 0;
}

rhi_translate :: inline (extent: Extent2D) -> VkExtent2D {
    return .{width = extent.width, height = extent.height};
}

rhi_translate :: inline (samples: RHISampleCount) -> VkSampleCountFlags {
    result: VkSampleCountFlags = 0;
    
    if test_flag_bit(samples, RHISampleCount._1) {
        result |= VkSampleCountFlags._1_BIT;
    }
    if test_flag_bit(samples, RHISampleCount._2) {
        result |= VkSampleCountFlags._2_BIT;
    }
    if test_flag_bit(samples, RHISampleCount._4) {
        result |= VkSampleCountFlags._4_BIT;
    }
    if test_flag_bit(samples, RHISampleCount._8) {
        result |= VkSampleCountFlags._8_BIT;
    }
    if test_flag_bit(samples, RHISampleCount._16) {
        result |= VkSampleCountFlags._16_BIT;
    }
    if test_flag_bit(samples, RHISampleCount._32) {
        result |= VkSampleCountFlags._32_BIT;
    }
    if test_flag_bit(samples, RHISampleCount._64) {
        result |= VkSampleCountFlags._64_BIT;
    }

    return result;
}

rhi_translate :: (flags: RHIImageCreateFlags) -> VkImageCreateFlags {
    result: VkImageCreateFlags = 0;

    if test_flag_bit(flags, RHIImageCreateFlags.MUTABLE_FORMAT_BIT) {
        result |= .MUTABLE_FORMAT_BIT;
    }
    if test_flag_bit(flags, RHIImageCreateFlags.CUBE_COMPATIBLE_BIT) {
        result |= .CUBE_COMPATIBLE_BIT;
    }
    if test_flag_bit(flags, RHIImageCreateFlags._2D_ARRAY_COMPATIBLE_BIT) {
        result |= ._2D_ARRAY_COMPATIBLE_BIT;
    }

    return result;
}

rhi_translate :: (flags: RHIMemoryPropertyFlags) -> VkMemoryPropertyFlags {
    result: VkMemoryPropertyFlags = 0;

    if test_flag_bit(flags, RHIMemoryPropertyFlags.DEVICE_LOCAL_BIT) {
        result |= .DEVICE_LOCAL_BIT;
    }
    if test_flag_bit(flags, RHIMemoryPropertyFlags.HOST_VISIBLE_BIT) {
        result |= .HOST_VISIBLE_BIT;
    }
    if test_flag_bit(flags, RHIMemoryPropertyFlags.HOST_COHERENT_BIT) {
        result |= .HOST_COHERENT_BIT;
    }
    if test_flag_bit(flags, RHIMemoryPropertyFlags.HOST_CACHED_BIT) {
        result |= .HOST_CACHED_BIT;
    }

    return result;
}

rhi_translate :: (flags: RHIImageUsageFlags) -> VkImageUsageFlags {
    result: VkImageUsageFlags = 0;

    if test_flag_bit(flags, RHIImageUsageFlags.TRANSFER_SRC_BIT) {
        result |= .TRANSFER_SRC_BIT;
    }
    if test_flag_bit(flags, RHIImageUsageFlags.TRANSFER_DST_BIT) {
        result |= .TRANSFER_DST_BIT;
    }
    if test_flag_bit(flags, RHIImageUsageFlags.TEXTURE_BIT) {
        result |= .SAMPLED_BIT;
    }
    if test_flag_bit(flags, RHIImageUsageFlags.RW_TEXTURE_BIT) {
        result |= .STORAGE_BIT;
    }
    if test_flag_bit(flags, RHIImageUsageFlags.COLOR_ATTACHMENT_BIT) {
        result |= .COLOR_ATTACHMENT_BIT;
    }
    if test_flag_bit(flags, RHIImageUsageFlags.DEPTH_STENCIL_ATTACHMENT_BIT) {
        result |= .DEPTH_STENCIL_ATTACHMENT_BIT;
    }
    if test_flag_bit(flags, RHIImageUsageFlags.CLEAR_BIT) {
        result |= .TRANSFER_DST_BIT;
    }

    return result;
}

rhi_translate :: (flags: RHIBufferCreateFlags) -> VkBufferCreateFlags {
    return 0;
}

rhi_translate :: (flags: RHIBufferUsageFlags) -> VkBufferUsageFlags {
    result: VkBufferUsageFlags = 0;

    if test_flag_bit(flags, RHIBufferUsageFlags.TRANSFER_SRC_BIT) {
        result |= .TRANSFER_SRC_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.TRANSFER_DST_BIT) {
        result |= .TRANSFER_DST_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.TYPED_BUFFER_BIT) {
        result |= .UNIFORM_TEXEL_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.RW_TYPED_BUFFER_BIT) {
        result |= .STORAGE_TEXEL_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.CONSTANT_BUFFER_BIT) {
        result |= .UNIFORM_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.BYTE_BUFFER_BIT) {
        result |= .STORAGE_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.RW_BYTE_BUFFER_BIT) {
        result |= .STORAGE_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.STRUCTURED_BUFFER_BIT) {
        result |= .STORAGE_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.RW_STRUCTURED_BUFFER_BIT) {
        result |= .STORAGE_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.INDEX_BUFFER_BIT) {
        result |= .INDEX_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.VERTEX_BUFFER_BIT) {
        result |= .VERTEX_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.INDIRECT_BUFFER_BIT) {
        result |= .INDIRECT_BUFFER_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.CLEAR_BIT) {
        result |= .TRANSFER_DST_BIT;
    }
    if test_flag_bit(flags, RHIBufferUsageFlags.SHADER_DEVICE_ADDRESS_BIT) {
        result |= .SHADER_DEVICE_ADDRESS_BIT;
    }

    return result;
}

rhi_translate :: (view_type: RHIImageViewType) -> VkImageViewType {
    if view_type == {
        case ._1D;
            return ._1D;
        case ._2D;
            return ._2D;
        case ._3D;
            return ._3D;
        case .CUBE;
            return .CUBE;
        case ._1D_ARRAY;
            return ._1D_ARRAY;
        case ._2D_ARRAY;
            return ._2D_ARRAY;
        case .CUBE_ARRAY;
            return .CUBE_ARRAY;
    }

    assert(false);
    return 0;
}

rhi_translate :: (swizzle: RHIComponentSwizzle) -> VkComponentSwizzle {
    if swizzle == {
        case .IDENTITY;
            return .IDENTITY;
        case .ZERO;
            return .ZERO;
        case .ONE;
            return .ONE;
        case .R;
            return .R;
        case .G;
            return .G;
        case .B;
            return .B;
        case .A;
            return .A;
    }

    assert(false);
    return 0;
}

#load "vk_device.jai";
#load "vk_semaphore.jai";
#load "vk_debug.jai";
#load "vk_resources.jai";
#load "vk_swapchain.jai";
#load "vk_descriptor_set.jai";
#load "vk_cmd_list.jai";
#load "vk_allocator.jai";

#import "Vulkan";