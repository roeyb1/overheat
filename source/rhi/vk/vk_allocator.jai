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
    vmaDestroyAllocator(vma);
}

rhi_find_memory_type :: (memory_type_requirements: u32, required_props: VkMemoryPropertyFlags, preferred_props: VkMemoryPropertyFlags) -> VkResult, u32 {
    best_memory_type_index: u32 = U32_MAX;
    best_set_count := -1;

    for memory_index : 0..memory_properties.memoryTypeCount-1 {
        is_required_type := memory_type_requirements & (1 << memory_index);

        properties := memory_properties.memoryTypes[memory_index].propertyFlags;
        has_required_props := (properties & required_props) == required_props;

        if is_required_type && has_required_props {
            present_bits := cast(u32) properties & preferred_props;

            if present_bits == cast(u32) preferred_props {
                return .SUCCESS, memory_index;
            }

            // only some are present, count the set bits so we can choose the one with the most if we don't find a perfect one
            set_count := 0;
            for bit : 0..31 {
                set_count += (present_bits & (1 << bit)) >> bit;
            }

            if set_count > best_set_count {
                best_set_count = set_count;
                best_memory_type_index = memory_index;
            }
        }
    }

    if best_memory_type_index == U32_MAX {
        return .SUCCESS, best_memory_type_index;
    }
    return .ERROR_FEATURE_NOT_PRESENT, 0;
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

    {
        //vk_check_result(vkCreateBuffer(device, *buffer_create_info, null, *buffer));

        //memory_requirements: VkMemoryRequirements;
        //vkGetBufferMemoryRequirements(device, buffer, *memory_requirements);

        //result, memory_type_index := rhi_find_memory_type(memory_requirements.memoryTypeBits, alloc_info.required_flags, alloc_info.preferred_flags);
        //vk_check_result(result);

        //vk_alloc_info: VkMemoryAllocateInfo;
        //vk_alloc_info.allocationSize = memory_requirements.size;
        //vk_alloc_info.memoryTypeIndex = memory_type_index;

        //buffer_memory: VkDeviceMemory;
        //vk_check_result(vkAllocateMemory(device, *vk_alloc_info, null, *buffer_memory));
        
        //vkBindBufferMemory(device, buffer, buffer_memory, 0);
    }
    
    return buffer, buffer_alloc;
}

#import "Vulkan_Memory_Allocator";