#scope_export

RHIImage :: struct {
    handle: VkImage;
    desc: RHIImageCreateInfo;
    memory: VkDeviceMemory;
}

RHIImageView :: struct {
    handle: VkImageView;
}

rhi_image_create :: (vk: VkImage, desc: RHIImageCreateInfo) -> RHIImage {
    return .{ handle = vk, desc = desc };
}

rhi_image_create :: (image_create_info: RHIImageCreateInfo, required_memory_prop_flags: RHIMemoryPropertyFlags, preferred_memory_prop_flags: RHIMemoryPropertyFlags, dedicated: bool) -> *RHIImage {
    create_info := VkImageCreateInfo.{
        flags = rhi_translate(image_create_info.create_flags),
        imageType = rhi_translate(image_create_info.image_type),
        format = rhi_translate(image_create_info.format),
        extent = .{ image_create_info.extent.width, image_create_info.extent.height, image_create_info.depth },
        mipLevels = image_create_info.levels,
        arrayLayers = image_create_info.layers,
        samples = rhi_translate(image_create_info.samples),
        tiling = .OPTIMAL,
        usage = rhi_translate(image_create_info.usage_flags),
        sharingMode = .EXCLUSIVE,
        queueFamilyIndexCount = 0,
        pQueueFamilyIndices = null,
        initialLayout = .UNDEFINED,
    };

    alloc_info := RHIAllocationCreateInfo.{
        dedicated_allocation = dedicated,
        required_flags = rhi_translate(required_memory_prop_flags),
        preferred_flags = rhi_translate(preferred_memory_prop_flags),
    };

    handle, device_memory := rhi_allocate_image(alloc_info, create_info);

    // #todo: use pool allocation instead of this garbage
    result: *RHIImage = alloc(size_of(RHIImage));
    << result = RHIImage.{ handle = handle, desc = image_create_info, memory = device_memory };

    return result;
}

rhi_image_destroy :: (image: RHIImage) {
    assert(image.handle != VK_NULL_HANDLE);

    vkDestroyImage(device, image.handle, null);
}

rhi_buffer_create :: (buffer_create_info: RHIBufferCreateInfo, required_flags: RHIMemoryPropertyFlags, preferred_flags: RHIMemoryPropertyFlags, dedicated: bool) -> *RHIBuffer {
    alloc_info := RHIAllocationCreateInfo.{
        dedicated_allocation = dedicated,
        preferred_flags = rhi_translate(preferred_flags),
        required_flags = rhi_translate(required_flags),
    };

    queue_family_indices := u32.[
        rhi_queues[RHIQueueType.GRAPHICS].queue_family_index,
        rhi_queues[RHIQueueType.COMPUTE].queue_family_index,
        rhi_queues[RHIQueueType.TRANSFER].queue_family_index,
    ];

    unique_queue_family_indices: [..] u32;
    unique_queue_family_indices.allocator = temp;

    array_add(*unique_queue_family_indices, queue_family_indices[0]);
    if queue_family_indices[1] != queue_family_indices[0] {
        array_add(*unique_queue_family_indices, queue_family_indices[1]);
    }
    if (queue_family_indices[2] != queue_family_indices[1]) && (queue_family_indices[2] != queue_family_indices[0]) {
        array_add(*unique_queue_family_indices, queue_family_indices[2]);
    }

    vk_buffer_create_info := VkBufferCreateInfo.{
        flags = rhi_translate(buffer_create_info.create_flags),
        size = buffer_create_info.size,
        usage = rhi_translate(buffer_create_info.usage_flags),
        sharingMode = .CONCURRENT,
        queueFamilyIndexCount = xx unique_queue_family_indices.count,
        pQueueFamilyIndices = unique_queue_family_indices.data,
    };

    handle, device_memory := rhi_allocate_buffer(alloc_info, vk_buffer_create_info);

    result: *RHIBuffer = alloc(size_of(RHIBuffer));
    << result = .{ handle = handle, memory = device_memory };
    return result;
}

rhi_image_view_destroy :: (image_view: RHIImageView) {
    assert(false); // nyi
}

RHIBuffer :: struct {
    handle: VkBuffer;
    memory: VkDeviceMemory;
}

RHIBufferView :: struct {
    handle: VkBufferView;
}

rhi_buffer_destroy :: (buffer: RHIBuffer) {
    assert(false); // nyi
}

rhi_buffer_view_destroy :: (buffer_view: RHIBufferView) {
    assert(false); // nyi
}

RHIResourceStateInfo :: struct {
    stage_mask: VkPipelineStageFlags = .TOP_OF_PIPE_BIT;
    access_mask: VkAccessFlags = 0;
    layout: VkImageLayout = .UNDEFINED;
    has_read_access: bool = false;
    has_write_access: bool = false;
}

rhi_get_resource_state_info :: (state: RHIResourceState, stage_flags: VkPipelineStageFlags, is_image: bool, image_format: RHIFormat) -> RHIResourceStateInfo {
    result: RHIResourceStateInfo;

    if state == .UNDEFINED {
        result = RHIResourceStateInfo.{
            stage_mask = .TOP_OF_PIPE_BIT,
            access_mask = 0,
            layout = .UNDEFINED,
            has_read_access = false,
            has_write_access = false
        };
        return result;
    }

    if (state & .READ_RESOURCE) != 0 {
        result.stage_mask |= stage_flags;
        result.access_mask |= .SHADER_READ_BIT;
        result.layout = ifx (rhi_is_depth_format(image_format) || rhi_is_stencil_format(image_format)) then .DEPTH_STENCIL_READ_ONLY_OPTIMAL else .SHADER_READ_ONLY_OPTIMAL;
        result.has_read_access = true;
    }

    if (state & .READ_DEPTH_STENCIL) != 0 {
        assert(is_image);
        result.stage_mask |= .EARLY_FRAGMENT_TESTS_BIT | .LATE_FRAGMENT_TESTS_BIT;
        result.access_mask |= .DEPTH_STENCIL_ATTACHMENT_READ_BIT;
        result.layout = .DEPTH_STENCIL_READ_ONLY_OPTIMAL;
        result.has_read_access = true;
    }

    if (state & .READ_CONSTANT_BUFFER) != 0 {
        assert(!is_image);
        result.stage_mask |= stage_flags;
        result.access_mask |= .UNIFORM_READ_BIT;
        result.has_read_access = true;
    }

    if (state & .READ_VERTEX_BUFFER) != 0 {
        assert(!is_image);
        result.stage_mask |= .VERTEX_INPUT_BIT;
        result.access_mask |= .VERTEX_ATTRIBUTE_READ_BIT;
        result.has_read_access = true;
    }

    if (state & .READ_INDEX_BUFFER) != 0 {
        assert(!is_image);
        result.stage_mask |= .VERTEX_INPUT_BIT;
        result.access_mask |= .INDEX_READ_BIT;
        result.has_read_access = true;
    }

    if (state & .READ_INDIRECT_BUFFER) != 0 {
        assert(!is_image);
        result.stage_mask |= .DRAW_INDIRECT_BIT;
        result.access_mask |= .INDIRECT_COMMAND_READ_BIT;
        result.has_read_access = true;
    }

    if (state & .READ_TRANSFER) != 0 {
        assert(!is_image || state == .READ_TRANSFER);
        result.stage_mask |= .TRANSFER_BIT;
        result.access_mask |= .TRANSFER_READ_BIT;
        result.layout = .TRANSFER_SRC_OPTIMAL;
        result.has_read_access = true;
    }

    if (state & .WRITE_DEPTH_STENCIL) != 0 {
        assert(is_image);
        assert(state == .WRITE_DEPTH_STENCIL);
        result.stage_mask = .EARLY_FRAGMENT_TESTS_BIT | .LATE_FRAGMENT_TESTS_BIT;
        result.access_mask = .DEPTH_STENCIL_ATTACHMENT_READ_BIT | .DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
        result.layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
        result.has_write_access = true;
    }

    if (state & .WRITE_COLOR_ATTACHMENT) != 0 {
        assert(is_image);
        assert(state == .WRITE_COLOR_ATTACHMENT);
        result.stage_mask = .COLOR_ATTACHMENT_OUTPUT_BIT;
        result.access_mask = .COLOR_ATTACHMENT_READ_BIT | .COLOR_ATTACHMENT_WRITE_BIT;
        result.layout = .COLOR_ATTACHMENT_OPTIMAL;
        result.has_write_access = true;
    }

    if (state & .WRITE_TRANSFER) != 0 {
        assert(state == .WRITE_TRANSFER);
        result.stage_mask = .TRANSFER_BIT;
        result.access_mask = .TRANSFER_WRITE_BIT;
        result.layout = .TRANSFER_DST_OPTIMAL;
        result.has_write_access = true;
    }

    if (state & .CLEAR_RESOURCE) != 0 {
        assert(state == .CLEAR_RESOURCE);
        result.stage_mask = .TRANSFER_BIT;
        result.access_mask = .TRANSFER_WRITE_BIT;
        result.layout = .TRANSFER_DST_OPTIMAL;
        result.has_write_access = true;
    }

    if (state & .RW_RESOURCE) != 0 {
        assert(state == .RW_RESOURCE);
        result.stage_mask = stage_flags;
        result.access_mask = .SHADER_READ_BIT | .SHADER_WRITE_BIT;
        result.layout = .GENERAL;
        result.has_read_access = true;
        result.has_write_access = true;
    }

    if (state & .RW_RESOURCE_READ_ONLY) != 0 {
        assert(state == .RW_RESOURCE_READ_ONLY);
        result.stage_mask = stage_flags;
        result.access_mask = .SHADER_READ_BIT;
        result.layout = .GENERAL;
        result.has_read_access = true;
        result.has_write_access = false;
    }

    if (state & .RW_RESOURCE_WRITE_ONLY) != 0 {
        assert(state == .RW_RESOURCE_WRITE_ONLY);
        result.stage_mask = stage_flags;
        result.access_mask = .SHADER_WRITE_BIT;
        result.layout = .GENERAL;
        result.has_read_access = false;
        result.has_write_access = true;
    }

    if (state & .PRESENT) != 0 {
        assert(is_image);
        assert(state == .PRESENT);
        result.stage_mask = .BOTTOM_OF_PIPE_BIT;
        result.access_mask = 0;
        result.layout = .PRESENT_SRC_KHR;
        result.has_read_access = true;
        result.has_write_access = false;
    }

    result.layout = ifx is_image then result.layout else .UNDEFINED;

    return result;
}