#scope_export

// Device resources:
physical_device: VkPhysicalDevice;
physical_device_properties: VkPhysicalDeviceProperties;

device: VkDevice;

RHIQueue :: struct {
    handle: VkQueue;
    queue_family_index: u32;
}

RHI_QUEUE_COUNT :: 3; 
RHIQueueIndex :: enum u32 {
    GRAPHICS    :: 0;
    COMPUTE     :: 1;
    TRANSFER    :: 2;
}
rhi_queues: [RHI_QUEUE_COUNT] RHIQueue;

RHISubmitInfo :: struct {
    wait_semaphore_count: u32;
    wait_semaphores: [] *RHISemaphore;
    wait_values: [] u64;
    wait_dst_stage_masks: [] RHIPipelineStageFlags;
    command_lists: [] *RHICmdList;
    signal_semaphores: [] *RHISemaphore;
    signal_values: [] u64;
}


vkCmdInsertDebugUtilsLabelEXT: PFN_vkCmdInsertDebugUtilsLabelEXT;
vkCmdBeginDebugUtilsLabelEXT: PFN_vkCmdBeginDebugUtilsLabelEXT;
vkCmdEndDebugUtilsLabelEXT: PFN_vkCmdEndDebugUtilsLabelEXT;
vkSetDebugUtilsObjectNameEXT: PFN_vkSetDebugUtilsObjectNameEXT;

init_device :: () {
    device_handles: [..] VkPhysicalDevice;
    device_handles.allocator = temp;
    queue_family_properties: [..] VkQueueFamilyProperties;
    queue_family_properties.allocator = temp;

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

        // test if device supports our required extensions:
        supports_dynamic_rendering := false;
        {
            ext_count: u32 = 0;
            available_extensions: [..] VkExtensionProperties;
            available_extensions.allocator = temp;
            vkEnumerateDeviceExtensionProperties(device_to_check, null, *ext_count, null);
            array_resize(*available_extensions, ext_count);
            vkEnumerateDeviceExtensionProperties(device_to_check, null, *ext_count, available_extensions.data);

            for ext : available_extensions {
                if to_string(ext.extensionName.data) == VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME {
                    supports_dynamic_rendering = true;
                }
            }
        }

        // We found all the queues we need and we support dynamic rendering, device is good enough
        if supports_dynamic_rendering && graphics_family_index != U32_MAX {
            physical_device = device_to_check;
            log("Selected physical device: % (Vendor %)", cast(string) device_properties.deviceName, device_properties.vendorID);
            break;
        }

    }

    if physical_device == VK_NULL_HANDLE {
        log_error("Failed to select a suitable physical device!");
        // #todo: report why we couldn't select it
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
    device_extensions.allocator = temp;
    array_add(*device_extensions, VK_KHR_SWAPCHAIN_EXTENSION_NAME.data);
    array_add(*device_extensions, VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME.data);

    device_features := VkPhysicalDeviceFeatures.{
        samplerAnisotropy = VK_TRUE,
        multiDrawIndirect = VK_TRUE,
    };

    dynamic_rendering_features := VkPhysicalDeviceDynamicRenderingFeatures.{
        dynamicRendering = VK_TRUE,
    };

    vk12_features := VkPhysicalDeviceVulkan12Features.{
        pNext = *dynamic_rendering_features,
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
    
    vkGetDeviceQueue(device, graphics_family_index, queueIndex=0, *rhi_queues[RHIQueueType.GRAPHICS].handle);
    vkGetDeviceQueue(device, transfer_family_index, queueIndex=0, *rhi_queues[RHIQueueType.TRANSFER].handle);

    // #todo: unique compute queue:
    rhi_queues[RHIQueueType.COMPUTE] = rhi_queues[RHIQueueType.GRAPHICS];

    // store the physical device properties for convenience:
    vkGetPhysicalDeviceProperties(physical_device, *physical_device_properties);


    // Load some optional debug function pointers from the device:
    vkCmdInsertDebugUtilsLabelEXT = cast(PFN_vkCmdInsertDebugUtilsLabelEXT) vkGetDeviceProcAddr(device, "vkCmdInsertDebugUtilsLabelEXT");
    vkCmdBeginDebugUtilsLabelEXT = cast(PFN_vkCmdBeginDebugUtilsLabelEXT) vkGetDeviceProcAddr(device, "vkCmdBeginDebugUtilsLabelEXT");
    vkCmdEndDebugUtilsLabelEXT = cast(PFN_vkCmdEndDebugUtilsLabelEXT) vkGetDeviceProcAddr(device, "vkCmdEndDebugUtilsLabelEXT");
    vkSetDebugUtilsObjectNameEXT = cast(PFN_vkSetDebugUtilsObjectNameEXT) vkGetDeviceProcAddr(device, "vkSetDebugUtilsObjectNameEXT");

    rhi_allocator_init();
}

destroy_device :: () {
    vkDestroyDevice(device, null);
}

rhi_device_wait_idle :: () {
    vkDeviceWaitIdle(device);
}

rhi_is_dynamic_rendering_ext_supported :: () -> bool {
    // #todo: support non-dynamic rendering ext path.
    return true;
}

rhi_queue_index :: inline (queue: *RHIQueue) -> RHIQueueIndex {
    if queue == *rhi_queues[0] {
        return RHIQueueIndex.GRAPHICS ;
    } else if queue == *rhi_queues[1] {
        return RHIQueueIndex.COMPUTE;
    } else {
        assert(queue == *rhi_queues[2]);
        return RHIQueueIndex.TRANSFER;
    }
}

rhi_queue_submit :: (queue: *RHIQueue, submit_infos: [] *RHISubmitInfo) {
    push_allocator(temp);

    semaphore_count: s64 = 0;
    command_buffer_count: s64 = 0;
    wait_mask_count: s64 = 0;

    for submit_info : submit_infos {
        semaphore_count += submit_info.wait_semaphore_count + submit_info.signal_semaphores.count;
        wait_mask_count += submit_info.wait_semaphore_count;
        command_buffer_count += submit_info.command_lists.count;
    }

    submit_infos_vk: [..] VkSubmitInfo;
    array_reserve(*submit_infos_vk, submit_infos.count);
    timeline_infos: [..] VkTimelineSemaphoreSubmitInfo;
    array_reserve(*timeline_infos, submit_infos.count);
    semaphore_handles: [..] VkSemaphore;
    array_reserve(*semaphore_handles, semaphore_count);
    wait_dst_stage_masks: [..] VkPipelineStageFlags;
    array_reserve(*wait_dst_stage_masks, wait_mask_count);
    command_buffers: [..] VkCommandBuffer;
    array_reserve(*command_buffers, command_buffer_count);

    for submit_info : submit_infos {
        wait_semaphore_submit_info_offset := semaphore_handles.count;
        command_buffers_submit_info_offset := command_buffers.count;
        wait_mask_submit_info_offset := wait_dst_stage_masks.count;

        if submit_info.wait_semaphore_count > 0 {
            for j : 0..submit_info.wait_semaphore_count-1 {
                array_add(*semaphore_handles, submit_info.wait_semaphores[j].handle);
                array_add(*wait_dst_stage_masks, rhi_translate(submit_info.wait_dst_stage_masks[j]));
            }
        }

        for cmd_buff : submit_info.command_lists {
            array_add(*command_buffers, cmd_buff.handle);
        }

        signal_semaphore_submit_info_offset := semaphore_handles.count;

        for signal_semaphore : submit_info.signal_semaphores {
            array_add(*semaphore_handles, signal_semaphore.handle);
        }

        timeline_info := array_add(*timeline_infos);
        timeline_info.waitSemaphoreValueCount = xx submit_info.wait_semaphore_count;
        timeline_info.pWaitSemaphoreValues = submit_info.wait_values.data;
        timeline_info.signalSemaphoreValueCount = xx submit_info.signal_values.count;
        timeline_info.pSignalSemaphoreValues = submit_info.signal_values.data;

        submit_info_vk: *VkSubmitInfo = array_add(*submit_infos_vk);
        submit_info_vk.pNext = timeline_info;
        submit_info_vk.waitSemaphoreCount = xx submit_info.wait_semaphore_count;
        submit_info_vk.pWaitSemaphores = semaphore_handles.data + wait_semaphore_submit_info_offset;
        submit_info_vk.pWaitDstStageMask = wait_dst_stage_masks.data + wait_mask_submit_info_offset;
        submit_info_vk.commandBufferCount = xx submit_info.command_lists.count;
        submit_info_vk.pCommandBuffers = command_buffers.data + command_buffers_submit_info_offset;
        submit_info_vk.signalSemaphoreCount = xx submit_info.signal_semaphores.count;
        submit_info_vk.pSignalSemaphores = semaphore_handles.data + signal_semaphore_submit_info_offset;
    }

    vk_check_result(vkQueueSubmit(queue.handle, xx submit_infos_vk.count, submit_infos_vk.data, VK_NULL_HANDLE));
}