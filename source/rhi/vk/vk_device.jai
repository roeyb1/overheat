#scope_export

// Device resources:
physical_device: VkPhysicalDevice;
physical_device_properties: VkPhysicalDeviceProperties;

device: VkDevice;

RHIQueue :: struct {
    handle: VkQueue;
    queue_family_index: u32;
}

graphics_queue: RHIQueue;
transfer_queue: RHIQueue;
// #todo: compute queue

init_device :: () {
    push_allocator(temp);

    device_handles: [..] VkPhysicalDevice;
    queue_family_properties: [..] VkQueueFamilyProperties;

    physical_device_count: u32 = 0;
    vkEnumeratePhysicalDevices(instance, *physical_device_count, null);
    array_resize(*device_handles, physical_device_count);
    vkEnumeratePhysicalDevices(instance, *physical_device_count, device_handles.data);

    has_dedicated_gpu := false;
    // First check if we have any dedicated gpus:
    for device_to_check : device_handles {
        device_properties: VkPhysicalDeviceProperties;
        vkGetPhysicalDeviceProperties(device_to_check, *device_properties);
        has_dedicated_gpu |= (device_properties.deviceType == .DISCRETE_GPU);
    }

    graphics_family_index: u32;
    transfer_family_index: u32;
    for device_to_check : device_handles {
        device_properties: VkPhysicalDeviceProperties;
        vkGetPhysicalDeviceProperties(device_to_check, *device_properties);
        // if we have a dedicated gpu, don't check any non-dedicated gpus
        if has_dedicated_gpu && device_properties.deviceType != .DISCRETE_GPU {
            continue;
        }

        queue_family_count: u32 = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(device_to_check, *queue_family_count, null);
        array_resize(*queue_family_properties, queue_family_count);
        vkGetPhysicalDeviceQueueFamilyProperties(device_to_check, *queue_family_count, queue_family_properties.data);

        graphics_family_index = U32_MAX;
        for queue_family : queue_family_properties {
            supports_present := VK_FALSE;
            vkGetPhysicalDeviceSurfaceSupportKHR(device_to_check, xx it_index, surface, *supports_present);

            if supports_present && (queue_family.queueFlags & .GRAPHICS_BIT) {
                graphics_family_index = xx it_index;
                break;
            }
        }
        transfer_family_index = U32_MAX;
        for queue_family : queue_family_properties {
            // Prefer separate transfer and graphics queues for better performance
            if it_index != graphics_family_index && (queue_family.queueFlags & .TRANSFER_BIT) {
                transfer_family_index = xx it_index;
                break;
            }
        }

        // If couldn't find dedicated transfer queue, just use the graphics queue for all operations:
        if transfer_family_index == U32_MAX {
            transfer_family_index = graphics_family_index;
        }

        // We found all the queues we need, this device is good enough
        if graphics_family_index != U32_MAX {
            physical_device = device_to_check;
            log("Selected physical device: % (Vendor %)", cast(string) device_properties.deviceName, device_properties.vendorID);
            break;
        }
    }

    if physical_device == VK_NULL_HANDLE {
        log_error("Failed to select a physical device that supports graphics and present operations in the same queue. (dedicated %)", has_dedicated_gpu);
        return;
    }

    unique_queue_families: [..] u32;

    array_add(*unique_queue_families, graphics_family_index);
    if unique_queue_families[0] != transfer_family_index {
        array_add(*unique_queue_families, transfer_family_index);
    }

    queue_create_infos: [..] VkDeviceQueueCreateInfo;
    queue_priority := 1.;
    for queue_family_index : unique_queue_families {
        queue_create_info := array_add(*queue_create_infos);
        queue_create_info.queueFamilyIndex = queue_family_index;
        queue_create_info.queueCount = 1;
        queue_create_info.pQueuePriorities = *queue_priority;
    }

    device_extensions: [..] *u8;
    array_add(*device_extensions, VK_KHR_SWAPCHAIN_EXTENSION_NAME.data);

    device_features := VkPhysicalDeviceFeatures.{
        samplerAnisotropy = VK_TRUE,
        multiDrawIndirect = VK_TRUE,
    };

    vk12_features := VkPhysicalDeviceVulkan12Features.{
        timelineSemaphore = VK_TRUE,
        descriptorIndexing = VK_TRUE,
        shaderInputAttachmentArrayDynamicIndexing = VK_TRUE,
        shaderUniformTexelBufferArrayDynamicIndexing = VK_TRUE,
        shaderStorageTexelBufferArrayDynamicIndexing = VK_TRUE,
        shaderUniformBufferArrayNonUniformIndexing = VK_TRUE,
        shaderSampledImageArrayNonUniformIndexing = VK_TRUE,
        shaderStorageBufferArrayNonUniformIndexing = VK_TRUE,
        shaderStorageImageArrayNonUniformIndexing = VK_TRUE,
        shaderInputAttachmentArrayNonUniformIndexing = VK_TRUE,
        shaderUniformTexelBufferArrayNonUniformIndexing = VK_TRUE,
        shaderStorageTexelBufferArrayNonUniformIndexing = VK_TRUE,
        descriptorBindingUniformBufferUpdateAfterBind = VK_TRUE,
        descriptorBindingSampledImageUpdateAfterBind = VK_TRUE,
        descriptorBindingStorageImageUpdateAfterBind = VK_TRUE,
        descriptorBindingStorageBufferUpdateAfterBind = VK_TRUE,
        descriptorBindingUniformTexelBufferUpdateAfterBind = VK_TRUE,
        descriptorBindingStorageTexelBufferUpdateAfterBind = VK_TRUE,
        descriptorBindingUpdateUnusedWhilePending = VK_TRUE,
        descriptorBindingPartiallyBound = VK_TRUE,
        descriptorBindingVariableDescriptorCount = VK_TRUE,
        runtimeDescriptorArray = VK_TRUE,
    };

    device_create_info: VkDeviceCreateInfo;
    device_create_info.queueCreateInfoCount = xx queue_create_infos.count;
    device_create_info.pQueueCreateInfos = queue_create_infos.data;
    device_create_info.enabledLayerCount = 0;
    device_create_info.ppEnabledLayerNames = null;

    device_create_info.enabledExtensionCount = xx device_extensions.count;
    device_create_info.ppEnabledExtensionNames = device_extensions.data;

    device_create_info.pEnabledFeatures = *device_features;
    device_create_info.pNext = *vk12_features;

    result := vkCreateDevice(physical_device, *device_create_info, null, *device);
    assert(result == .SUCCESS);
    
    vkGetDeviceQueue(device, graphics_family_index, queueIndex=0, *graphics_queue.handle);
    vkGetDeviceQueue(device, transfer_family_index, queueIndex=0, *transfer_queue.handle);

    // store the physical device properties for convenience:
    vkGetPhysicalDeviceProperties(physical_device, *physical_device_properties);
}

destroy_device :: () {
    vkDestroyDevice(device, null);
}
