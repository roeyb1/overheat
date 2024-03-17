#scope_export

RHIAllocationCreateInfo :: struct {
    required_flags: VkMemoryPropertyFlags;
    preferred_flags: VkMemoryPropertyFlags;
    dedicated_allocation: bool;
}

RHIAllocInfo :: struct {
    memory: VkDeviceMemory;
    offset: VkDeviceSize;
    size: VkDeviceSize;
    memory_type: u32;
    pool_index: u64;
    block_index: u64;
    map_count: u64;
    pool_data: *void;
}

RHIGpuMemoryPool :: struct {
    MAX_BLOCKS :: 16;

    memory_type: u32 = U32_MAX;
    heap_index: u32 = U32_MAX;
    buffer_image_granularity: VkDeviceSize = 0;
    preferred_block_size: VkDeviceSize = 0;
    heap_usage: *VkDeviceSize = null;
    heap_size_limit: VkDeviceSize = 0;
    block_sizes: [MAX_BLOCKS] VkDeviceSize;
    memory: [MAX_BLOCKS] VkDeviceMemory;
    mapped_ptr: [MAX_BLOCKS] *void;
    map_count: [MAX_BLOCKS] u64;

    use_memory_budget_ext: bool = false;
}

RHIGpuAllocator :: struct {
    memory_properties: VkPhysicalDeviceMemoryProperties;
    buffer_image_granularity: VkDeviceSize = 0;
    non_coherent_atom_size: VkDeviceSize = 0;
    use_memory_budget_ext: bool;

    heap_size_limits: [VK_MAX_MEMORY_HEAPS] VkDeviceSize;
    heap_usage: [VK_MAX_MEMORY_HEAPS] VkDeviceSize;
    pools: [VK_MAX_MEMORY_TYPES] RHIGpuMemoryPool;
}

gpu_allocator: RHIGpuAllocator;

#scope_file

MAX_BLOCK_SIZE :: 256 * 1024 * 1024;

#scope_export


rhi_allocator_init :: () {
    using gpu_allocator;

    vkGetPhysicalDeviceMemoryProperties(physical_device, *memory_properties);
    //device_properties: VkPhysicalDeviceProperties;
    //vkGetPhysicalDeviceProperties(physical_device, *device_properties);

    //buffer_image_granularity = device_properties.limits.bufferImageGranularity;
    //non_coherent_atom_size = device_properties.limits.nonCoherentAtomSize;

    //for 0..memory_properties.memoryHeapCount-1 {
    //    heap_size_limits[it] = memory_properties.memoryHeaps[it].size;
    //}
    //for 0..memory_properties.memoryTypeCount-1 {
    //    heap_index := memory_properties.memoryTypes[it].heapIndex;
    //    heap := *memory_properties.memoryHeaps[heap_index];

    //    preferred_block_size := ifx heap.size < MAX_BLOCK_SIZE then heap.size else MAX_BLOCK_SIZE;

    //    rhi_allocator_pool_init(*pools[it], it, heap_index, buffer_image_granularity, preferred_block_size, *heap_usage[heap_index], heap_size_limits[heap_index], use_memory_budget_ext);
    //}
}

rhi_allocator_pool_init :: (pool: *RHIGpuMemoryPool, memory_type: u32, heap_index: u32, buffer_image_granularity: VkDeviceSize, preferred_block_size: VkDeviceSize, heap_usage: *VkDeviceSize, heap_size_limit: VkDeviceSize, use_memory_budget_ext: bool) {
    pool.memory_type = memory_type;
    pool.heap_index = heap_index;
    pool.buffer_image_granularity = buffer_image_granularity;
    pool.preferred_block_size = preferred_block_size;
    pool.heap_usage = heap_usage;
    pool.heap_size_limit = heap_size_limit;
    pool.use_memory_budget_ext = use_memory_budget_ext;

    // memzero arrays?
    array_zero(pool.block_sizes);
    array_zero(pool.memory);
    array_zero(pool.mapped_ptr);
    array_zero(pool.map_count);
}

rhi_allocator_pool_alloc :: (using pool: *RHIGpuMemoryPool, size: VkDeviceSize, alignment: VkDeviceSize) -> (VkResult, RHIAllocInfo) {
    /*
    // try alloc from existing blocks:
    for 0..MAX_BLOCKS-1 {
        if block_sizes[it] >= size {
            success, alloc_info := rhi_allocator_pool_alloc_from_block(pool, it, size, alignment);
            if success {
                return VK_SUCCESS, alloc_info;
            }
        }
    }

    // create a new block
    block_index := U64_MAX;
    for 0..MAX_BLOCKS-1 {
        if block_sizes[it] == 0 {
            block_index = it;
            break;
        }
    }

    if block_index > MAX_BLOCKS {
        return .ERROR_OUT_OF_MEMORY, .{};
    }

    memory_budget, used_memory := rhi_allocator_pool_alloc_get_budget(pool);

    max_in_budget_allocation_size := ifx memory_budget > used_memory then (memory_budget - used_memory) else 0;

    // try to stay in budget. If we have enough memory we should alloc the preferred block size:
    alloc_size: VkDeviceSize = ifx max_in_budget_allocation_size < preferred_block_size then max_in_budget_allocation_size else preferred_block_size;

    // if we needed to allocate more:
    alloc_size = ifx size > alloc_size then size else alloc_size;

    memory_alloc_info := VkMemoryAllocateInfo.{
        allocationSize = alloc_size,
        memoryTypeIndex = memory_type,
    };

    if vkAllocateMemory(device, *memory_alloc_info, null, *memory[block_index]) != VK_SUCCESS {
        return .ERROR_OUT_OF_DEVICE_MEMORY, .{};
    }

    (<< heap_usage) += memory_allocate_info.allocationSize;

    block_sizes[block_index] = memory_alloc_info.allocationSize;

    success, alloc_info := rhi_allocator_pool_alloc_from_block(pool, block_index, size, alignment);
    if success {
        return VK_SUCCESS, alloc_info;
    }
    */
    return .ERROR_OUT_OF_DEVICE_MEMORY, .{};
}

rhi_find_memory_type :: (memory_type_requirements: u32, required_props: VkMemoryPropertyFlags, preferred_props: VkMemoryPropertyFlags) -> VkResult, u32 {
    best_memory_type_index: u32 = U32_MAX;
    best_set_count := -1;

    memory_properties := *gpu_allocator.memory_properties;

    for memory_index : 0..gpu_allocator.memory_properties.memoryTypeCount-1 {
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

rhi_allocate_image :: (alloc_info: RHIAllocationCreateInfo, image_create_info: VkImageCreateInfo) -> (VkImage, VkDeviceMemory) {
    image: VkImage;
    vk_check_result(vkCreateImage(device, *image_create_info, null, *image));
    
    memory_requirements: VkMemoryRequirements;
    vkGetImageMemoryRequirements(device, image, *memory_requirements);

    result, memory_type_index := rhi_find_memory_type(memory_requirements.memoryTypeBits, alloc_info.required_flags, alloc_info.preferred_flags);
    vk_check_result(result);

    vk_alloc_info: VkMemoryAllocateInfo;
    vk_alloc_info.allocationSize = memory_requirements.size;
    vk_alloc_info.memoryTypeIndex = memory_type_index;

    image_memory: VkDeviceMemory;
    vk_check_result(vkAllocateMemory(device, *vk_alloc_info, null, *image_memory));
    
    vkBindImageMemory(device, image, image_memory, 0);

    return image, image_memory;
}

rhi_allocate_buffer :: (alloc_info: RHIAllocationCreateInfo, buffer_create_info: VkBufferCreateInfo) -> (VkBuffer, VkDeviceMemory) {
    buffer: VkBuffer;
    vk_check_result(vkCreateBuffer(device, *buffer_create_info, null, *buffer));

    memory_requirements: VkMemoryRequirements;
    vkGetBufferMemoryRequirements(device, buffer, *memory_requirements);

    result, memory_type_index := rhi_find_memory_type(memory_requirements.memoryTypeBits, alloc_info.required_flags, alloc_info.preferred_flags);
    vk_check_result(result);

    vk_alloc_info: VkMemoryAllocateInfo;
    vk_alloc_info.allocationSize = memory_requirements.size;
    vk_alloc_info.memoryTypeIndex = memory_type_index;

    buffer_memory: VkDeviceMemory;
    vk_check_result(vkAllocateMemory(device, *vk_alloc_info, null, *buffer_memory));
    
    vkBindBufferMemory(device, buffer, buffer_memory, 0);
    
    return buffer, buffer_memory;
}