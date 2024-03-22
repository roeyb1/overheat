#scope_export

MAX_SWAPCHAIN_IMAGES : u32 : 3;
MAX_FRAMES_IN_FLIGHT : u32 : 3;

PRESENT_MODE :: RHIPresentMode.V_SYNC;

RHISwapchain :: struct {
    handle: VkSwapchainKHR;
    surface: VkSurfaceKHR;

    present_queue: *RHIQueue;

    format: RHIFormat;
    present_mode: RHIPresentMode;
    extent: Extent2D;

    images: [MAX_SWAPCHAIN_IMAGES] RHIImage;
    image_count: u32;

    acquire_semaphores: [MAX_FRAMES_IN_FLIGHT] VkSemaphore;
    present_semaphores: [MAX_FRAMES_IN_FLIGHT] VkSemaphore;

    current_image_index: u32 = U32_MAX;
    frame_index: u32 = 0;
}

swapchain: RHISwapchain;

rhi_swapchain_init :: (width: u32, height: u32) {
    select_surface_format :: (formats: [] VkSurfaceFormatKHR) -> VkSurfaceFormatKHR {
        for formats {
            if it.format == .B8G8R8A8_UNORM && it.colorSpace == .COLOR_SPACE_SRGB_NONLINEAR_KHR {
                return it;
            }
        }

        return formats[0];
    }

    select_present_mode :: (present_modes: [] VkPresentModeKHR) -> VkPresentModeKHR {
        for present_modes {
            if PRESENT_MODE == .V_SYNC && it == .MAILBOX_KHR {
                return it;
            } else if PRESENT_MODE == .IMMEDIATE && it == .IMMEDIATE_KHR {
                return it;
            }
        }
        // FIFO is always supported
        return .FIFO_KHR;
    }

    select_extent :: (surface_capabilities: VkSurfaceCapabilitiesKHR, extent: VkExtent2D) -> VkExtent2D {
        if surface_capabilities.currentExtent.width != U32_MAX {
            return surface_capabilities.currentExtent;
        } else {
            return VkExtent2D.{
                width = max(surface_capabilities.minImageExtent.width, min(surface_capabilities.maxImageExtent.width, extent.width)),
                height = max(surface_capabilities.minImageExtent.height, min(surface_capabilities.maxImageExtent.height, extent.height)),
            };
        }
    }

    surface_capabilities: VkSurfaceCapabilitiesKHR;

    push_allocator(temp);

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, *surface_capabilities);

    format_count: u32 = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, *format_count, null);
    formats: [..] VkSurfaceFormatKHR;
    array_resize(*formats, format_count);
    vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, *format_count, formats.data);

    present_mode_count: u32 = 0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, *present_mode_count, null);
    present_modes: [..] VkPresentModeKHR;
    vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, *present_mode_count, present_modes.data);

    format := select_surface_format(formats);
    present_mode := select_present_mode(present_modes);
    extent := select_extent(surface_capabilities, VkExtent2D.{width = width, height = height});

    image_count := surface_capabilities.minImageCount + 1;
    if surface_capabilities.maxImageCount > 0 && image_count > surface_capabilities.maxImageCount {
        image_count = surface_capabilities.maxImageCount;
    }
    image_count = max(MAX_SWAPCHAIN_IMAGES, image_count);

    create_info := VkSwapchainCreateInfoKHR.{
        surface = surface,
        minImageCount = image_count,
        imageFormat = format.format,
        imageColorSpace = format.colorSpace,
        imageExtent = extent,
        imageArrayLayers = 1,
        imageUsage = .TRANSFER_DST_BIT | .STORAGE_BIT | .COLOR_ATTACHMENT_BIT | .SAMPLED_BIT,
        imageSharingMode = .EXCLUSIVE,
        preTransform = surface_capabilities.currentTransform,
        compositeAlpha = .OPAQUE_BIT_KHR,
        presentMode = present_mode,
        clipped = VK_TRUE,
    };

    vk_check_result(vkCreateSwapchainKHR(device, *create_info, null, *swapchain.handle));

    vk_images: [MAX_SWAPCHAIN_IMAGES] VkImage;
    vk_check_result(vkGetSwapchainImagesKHR(device, swapchain.handle, *image_count, vk_images.data));

    image_desc := RHIImageCreateInfo.{
        extent = .{width = extent.width, height = extent.height},
        depth = 1,
        layers = 1,
        levels = 1,
        samples = ._1,
        image_type = ._2D,
        format = cast(RHIFormat) format.format,
        usage_flags = .TRANSFER_DST_BIT | .RW_TEXTURE_BIT | .COLOR_ATTACHMENT_BIT | .TEXTURE_BIT,
    };

    for 0..image_count-1 {
        swapchain.images[it] = rhi_image_create(vk_images[it], image_desc);
    }

    swapchain.format = cast(RHIFormat) format.format;
    swapchain.extent = xx extent;
    swapchain.image_count = image_count;
    swapchain.present_mode = PRESENT_MODE;
    swapchain.present_queue = *rhi_queues[RHIQueueType.GRAPHICS];
    assert(swapchain.present_queue != null);

    semaphore_create_info := VkSemaphoreCreateInfo.{};
    for 0..MAX_FRAMES_IN_FLIGHT-1 {
        vk_check_result(vkCreateSemaphore(device, *semaphore_create_info, null, *swapchain.acquire_semaphores[it]));
        vk_check_result(vkCreateSemaphore(device, *semaphore_create_info, null, *swapchain.present_semaphores[it]));
    }
}

rhi_swapchain_destroy :: () {
    vkDestroySwapchainKHR(device, swapchain.handle, null);

    for 0..MAX_FRAMES_IN_FLIGHT-1 {
        vkDestroySemaphore(device, swapchain.acquire_semaphores[it], null);
        vkDestroySemaphore(device, swapchain.present_semaphores[it], null);
        swapchain.acquire_semaphores[it] = VK_NULL_HANDLE;
        swapchain.present_semaphores[it] = VK_NULL_HANDLE;
    }

    // Nothing to do for images
    //for 0..swapchain.image_count-1 {
    //}
}

rhi_swapchain_resize :: (width: u32, height: u32, $acquire_image: bool = false) {
    vkDeviceWaitIdle(device);
    rhi_swapchain_destroy();
    rhi_swapchain_init(width, height);

    #if acquire_image {
        swapchain.current_image_index = rhi_swapchain_acquire_image_index(null);
    }
}

rhi_swapchain_acquire_image_index :: (semaphore: *VkSemaphore) -> u32 {
    fence: VkFence = VK_NULL_HANDLE;

    if semaphore == null {
        fence_create_info := VkFenceCreateInfo.{};
        vk_check_result(vkCreateFence(device, *fence_create_info, null, *fence));
    }

    image_index: u32;
    result := vkAcquireNextImageKHR(device, swapchain.handle, U64_MAX, ifx semaphore then (<< semaphore) else VK_NULL_HANDLE, fence, *image_index);

    resized := false;
    if result == .ERROR_OUT_OF_DATE_KHR {
        rhi_swapchain_resize(swapchain.extent.width, swapchain.extent.height);
        // try again after resize:
        result = vkAcquireNextImageKHR(device, swapchain.handle, U64_MAX, ifx semaphore then (<< semaphore) else VK_NULL_HANDLE, VK_NULL_HANDLE, *image_index);
    }

    if fence != VK_NULL_HANDLE {
        vk_check_result(vkWaitForFences(device, 1, *fence, VK_TRUE, U64_MAX));
        vkDestroyFence(device, fence, null);
    }

    return image_index;
}

rhi_swapchain_image_index :: () -> u32 {
    // If we haven't yet presented, grab our image index:
    if swapchain.frame_index == 0 && swapchain.current_image_index == U32_MAX {
        swapchain.current_image_index = rhi_swapchain_acquire_image_index(null);
    }

    return cast(u32) swapchain.current_image_index;
}

rhi_swapchain_present :: (wait_semaphore: VkSemaphore, wait_value: u64, signal_semaphore: VkSemaphore, signal_value: u64) {
    frame_index := swapchain.frame_index % MAX_FRAMES_IN_FLIGHT;

    {
        wait_dst_stage_flags := VkPipelineStageFlags.TOP_OF_PIPE_BIT;

        dummy: u64 = 0;
        timeline_submit_info := VkTimelineSemaphoreSubmitInfo.{
            waitSemaphoreValueCount = 1,
            pWaitSemaphoreValues = *wait_value,
            signalSemaphoreValueCount = 1,
            pSignalSemaphoreValues = *dummy,
        };

        submit_info := VkSubmitInfo.{
            pNext = *timeline_submit_info,
            waitSemaphoreCount = 1,
            pWaitSemaphores = *wait_semaphore,
            pWaitDstStageMask = *wait_dst_stage_flags,
            commandBufferCount = 0,
            pCommandBuffers = null,
            signalSemaphoreCount = 1,
            pSignalSemaphores = *swapchain.present_semaphores[frame_index],
        };

        vk_check_result(vkQueueSubmit(swapchain.present_queue.handle, 1, *submit_info, null));
    }

    present_info := VkPresentInfoKHR.{
        waitSemaphoreCount = 1,
        pWaitSemaphores = *swapchain.present_semaphores[frame_index],
        swapchainCount = 1,
        pSwapchains = *swapchain.handle,
        pImageIndices = *swapchain.current_image_index,
    };

    vk_check_result(vkQueuePresentKHR(swapchain.present_queue.handle, *present_info));

    swapchain.current_image_index = rhi_swapchain_acquire_image_index(*swapchain.acquire_semaphores[frame_index]);


    {
        wait_dst_stage_flags := VkPipelineStageFlags.TOP_OF_PIPE_BIT;

        dummy: u64 = 0;
        timeline_submit_info := VkTimelineSemaphoreSubmitInfo.{
            waitSemaphoreValueCount = 1,
            pWaitSemaphoreValues = *dummy,
            signalSemaphoreValueCount = 1,
            pSignalSemaphoreValues = *signal_value,
        };

        submit_info := VkSubmitInfo.{
            pNext = *timeline_submit_info,
            waitSemaphoreCount = 1,
            pWaitSemaphores = *swapchain.acquire_semaphores[frame_index],
            pWaitDstStageMask = *wait_dst_stage_flags,
            commandBufferCount = 0,
            pCommandBuffers = null,
            signalSemaphoreCount = 1,
            pSignalSemaphores = *signal_semaphore,
        };

        vk_check_result(vkQueueSubmit(swapchain.present_queue.handle, 1, *submit_info, null));
    }
}