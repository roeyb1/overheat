#scope_export

vk_check_result :: inline (result: VkResult) -> bool {
    // switch copied from glfw/vulkan.c
    if result == .SUCCESS then return true;

    log_error("Vulkan error: %", get_vk_error(result));
    return false;
}

rhi_debug_set_object_name :: (image: *RHIImage, name: string) {
    #if VULKAN_DEBUG {
        c_name := temp_c_string(name);
        info := VkDebugUtilsObjectNameInfoEXT.{
            pObjectName = c_name,
            objectType = .IMAGE,
            objectHandle = xx image.handle,
        };

        vk_check_result(vkSetDebugUtilsObjectNameEXT(device, *info));

        if image.alloc {
            vmaSetAllocationName(vma, image.alloc, temp_c_string(tprint("% Memory", c_name)));
        }
    }
}

rhi_debug_set_object_name :: (buffer: *RHIBuffer, name: string) {
    #if VULKAN_DEBUG {
        c_name := temp_c_string(name);
        info := VkDebugUtilsObjectNameInfoEXT.{
            pObjectName = c_name,
            objectType = .BUFFER,
            objectHandle = xx buffer.handle,
        };

        vk_check_result(vkSetDebugUtilsObjectNameEXT(device, *info));

        if buffer.alloc {
            vmaSetAllocationName(vma, buffer.alloc, temp_c_string(tprint("% Memory", c_name)));
        }
    }
}

rhi_debug_set_object_name :: (image_view: *RHIImageView, name: string) {
    #if VULKAN_DEBUG {
        info := VkDebugUtilsObjectNameInfoEXT.{
            pObjectName = temp_c_string(name),
            objectType = .IMAGE_VIEW,
            objectHandle = xx image_view.handle,
        };

        vk_check_result(vkSetDebugUtilsObjectNameEXT(device, *info));
    }
}

rhi_debug_set_object_name :: (buffer_view: *RHIBufferView, name: string) {
    #if VULKAN_DEBUG {
        info := VkDebugUtilsObjectNameInfoEXT.{
            pObjectName = temp_c_string(name),
            objectType = .BUFFER_VIEW,
            objectHandle = xx buffer_view.handle,
        };

        vk_check_result(vkSetDebugUtilsObjectNameEXT(device, *info));
    }
}

#if VULKAN_DEBUG {
    validation_callback :: (flags: VkDebugReportFlagsEXT, objType: VkDebugReportObjectTypeEXT, obj: u64, location: u64, code: s32, layerPrefix: *u8, msg: *u8, userData: *void) -> VkBool32 #c_call {
        new_context: Context;
        new_context.logger = logger;
        push_context new_context {
            log("VULKAN VALIDATION: %\n", to_string(msg));
        }
        
        DebugBreak();
        return VK_FALSE;
    }

    debug_callback :: (messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, messageTypes: VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT, pUserData: *void) -> VkBool32 #c_call {
        new_context: Context;
        new_context.logger = logger;
        push_context new_context {
            if messageSeverity == {
                //case .INFO_BIT_EXT;
                //    log("Vulkan debug: %", to_string(pCallbackData.pMessage));
                case .WARNING_BIT_EXT;
                    log_warning("Vulkan debug: %", to_string(pCallbackData.pMessage));
                case .ERROR_BIT_EXT;
                    log_error("Vulkan debug: %", to_string(pCallbackData.pMessage));
            }
        }

        return VK_FALSE;
    }
}

#scope_file

get_vk_error :: (result: VkResult) -> string {
    if result ==  {
        case .NOT_READY;
            return "A fence or query has not yet completed";
        case .TIMEOUT;
            return "A wait operation has not completed in the specified time";
        case .EVENT_SET;
            return "An event is signaled";
        case .EVENT_RESET;
            return "An event is unsignaled";
        case .INCOMPLETE;
            return "A return array was too small for the result";
        case .ERROR_OUT_OF_HOST_MEMORY;
            return "A host memory allocation has failed";
        case .ERROR_OUT_OF_DEVICE_MEMORY;
            return "A device memory allocation has failed";
        case .ERROR_INITIALIZATION_FAILED;
            return "Initialization of an object could not be completed for implementation-specific reasons";
        case .ERROR_DEVICE_LOST;
            return "The logical or physical device has been lost";
        case .ERROR_MEMORY_MAP_FAILED;
            return "Mapping of a memory object has failed";
        case .ERROR_LAYER_NOT_PRESENT;
            return "A requested layer is not present or could not be loaded";
        case .ERROR_EXTENSION_NOT_PRESENT;
            return "A requested extension is not supported";
        case .ERROR_FEATURE_NOT_PRESENT;
            return "A requested feature is not supported";
        case .ERROR_INCOMPATIBLE_DRIVER;
            return "The requested version of Vulkan is not supported by the driver or is otherwise incompatible";
        case .ERROR_TOO_MANY_OBJECTS;
            return "Too many objects of the type have already been created";
        case .ERROR_FORMAT_NOT_SUPPORTED;
            return "A requested format is not supported on this device";
        case .ERROR_SURFACE_LOST_KHR;
            return "A surface is no longer available";
        case .SUBOPTIMAL_KHR;
            return "A swapchain no longer matches the surface properties exactly, but can still be used";
        case .ERROR_OUT_OF_DATE_KHR;
            return "A surface has changed in such a way that it is no longer compatible with the swapchain";
        case .ERROR_INCOMPATIBLE_DISPLAY_KHR;
            return "The display used by a swapchain does not use the same presentable image layout";
        case .ERROR_NATIVE_WINDOW_IN_USE_KHR;
            return "The requested window is already connected to a VkSurfaceKHR, or to some other non-Vulkan API";
        case .ERROR_VALIDATION_FAILED_EXT;
            return "A validation layer found an error";
        case;
            return "ERROR: UNKNOWN VULKAN ERROR";
    };
}