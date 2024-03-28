#scope_export

RHIAllocationCreateInfo :: struct {
    required_flags: VkMemoryPropertyFlags;
    preferred_flags: VkMemoryPropertyFlags;
    dedicated_allocation: bool;
}

vma: VmaAllocator;
memory_properties: VkPhysicalDeviceMemoryProperties;

rhi_allocator_init :: () {
    vkGetPhysicalDeviceMemoryProperties(physical_device, *memory_properties);

    allocator_info := VmaAllocatorCreateInfo.{
        physicalDevice = physical_device,
        device = device,
        instance = instance,
        vulkanApiVersion = vk_api_version(),
        flags = 0,
    };

    vk_check_result(vmaCreateAllocator(*allocator_info, *vma));
}

rhi_allocator_destroy :: () {
    #if DEBUG {
        memory_stats: VmaTotalStatistics;
        vmaCalculateStatistics(vma, *memory_stats);
        if memory_stats.total.statistics.allocationCount > 0 {
            log_error("Vulkan memory leaks! % allocations remained", memory_stats.total.statistics.allocationCount);
        }
    }

    vmaDestroyAllocator(vma);
}

rhi_allocate_image :: (alloc_info: RHIAllocationCreateInfo, image_create_info: VkImageCreateInfo) -> (VkImage, VmaAllocation) {
    alloc_create_info := VmaAllocationCreateInfo.{
        requiredFlags = alloc_info.required_flags,
        preferredFlags = alloc_info.preferred_flags,
    };

    image: VkImage;
    alloc: VmaAllocation;
    vma_alloc_info := VmaAllocationInfo.{};

    vk_check_result(vmaCreateImage(vma, *image_create_info, *alloc_create_info, *image, *alloc, *vma_alloc_info));

    return image, alloc;
}

rhi_allocate_buffer :: (alloc_info: RHIAllocationCreateInfo, buffer_create_info: VkBufferCreateInfo) -> (VkBuffer, VmaAllocation) {

    alloc_create_info := VmaAllocationCreateInfo.{
        requiredFlags = alloc_info.required_flags,
        preferredFlags = alloc_info.preferred_flags,
    };

    buffer: VkBuffer;
    buffer_alloc: VmaAllocation;
    buffer_alloc_info := VmaAllocationInfo.{};

    vk_check_result(vmaCreateBuffer(vma, *buffer_create_info, *alloc_create_info, *buffer, *buffer_alloc, *buffer_alloc_info));
    
    return buffer, buffer_alloc;
}

rhi_free_image :: (image: RHIImage) {
    vmaDestroyImage(vma, image.handle, image.alloc);
}

rhi_free_buffer :: (buffer: RHIBuffer) {
    vmaDestroyBuffer(vma, buffer.handle, buffer.alloc);
}

#import "Vulkan_Memory_Allocator";