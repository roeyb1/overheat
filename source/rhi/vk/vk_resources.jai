#scope_export

RHIImage :: struct {
    handle: VkImage;
    desc: RHIImageCreateInfo;
    alloc: VmaAllocation;
}

RHIImageView :: struct {
    handle: VkImageView;
    desc: RHIImageViewCreateInfo;
}

RHIBuffer :: struct {
    handle: VkBuffer;
    alloc: VmaAllocation;
    desc: RHIBufferCreateInfo;
}

RHIBufferView :: struct {
    handle: VkBufferView;
    desc: RHIBufferViewCreateInfo;
}

RHISampler:: struct {
    handle: VkSampler;
}

RHIResourceStateInfo :: struct {
    stage_mask: VkPipelineStageFlags = .TOP_OF_PIPE_BIT;
    access_mask: VkAccessFlags = 0;
    layout: VkImageLayout = .UNDEFINED;
    has_read_access: bool = false;
    has_write_access: bool = false;
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

    handle, vma_alloc := rhi_allocate_image(alloc_info, create_info);

    // #todo: use pool allocation instead of this garbage
    result: *RHIImage = alloc(size_of(RHIImage));
    << result = RHIImage.{ handle = handle, desc = image_create_info, alloc = vma_alloc };

    return result;
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

    handle, vma_alloc := rhi_allocate_buffer(alloc_info, vk_buffer_create_info);

    // #todo: allocate from a pool
    result: *RHIBuffer = alloc(size_of(RHIBuffer));
    << result = .{ handle = handle, alloc = vma_alloc, desc = buffer_create_info};
    return result;
}

rhi_buffer_map :: (buffer: *RHIBuffer) -> *void {
    ptr: *void = null;

    vk_check_result(vmaMapMemory(vma, buffer.alloc, *ptr));
    return ptr;
}
rhi_buffer_unmap :: (buffer: *RHIBuffer) {
    vmaUnmapMemory(vma, buffer.alloc);
}

rhi_image_view_create :: (create_info: RHIImageViewCreateInfo) -> *RHIImageView {
    vk_create_info := VkImageViewCreateInfo.{
        image = create_info.image.handle,
        viewType = rhi_translate(create_info.view_type),
        format = rhi_translate(ifx create_info.format == .UNDEFINED then create_info.image.desc.format else create_info.format),
        components.r = rhi_translate(create_info.components.r),
        components.g = rhi_translate(create_info.components.g),
        components.b = rhi_translate(create_info.components.b),
        components.a = rhi_translate(create_info.components.a),
        subresourceRange = VkImageSubresourceRange.{
            aspectMask = rhi_image_aspect_mask(rhi_translate(create_info.image.desc.format)),
            baseMipLevel = create_info.base_mip_level,
            baseArrayLayer = create_info.base_array_layer,
            levelCount = create_info.level_count,
            layerCount = create_info.layer_count,
        },
    };

    image_view: VkImageView = VK_NULL_HANDLE;
    vk_check_result(vkCreateImageView(device, *vk_create_info, null, *image_view));

    // #todo: allocate from a pool
    result: *RHIImageView = alloc(size_of(RHIImageView));
    << result = .{handle = image_view, desc = create_info};
    return result;
}

rhi_image_view_create :: (image: *RHIImage) -> *RHIImageView {
    create_info := RHIImageViewCreateInfo.{
        image = image,
        view_type = cast, force(RHIImageViewType) image.desc.image_type,
        format = image.desc.format,
        base_mip_level = 0,
        level_count = image.desc.levels,
        base_array_layer = 0,
        layer_count = image.desc.layers,
    };

    if create_info.view_type != .CUBE && create_info.layer_count > 1 {
        if create_info.view_type == {
            case ._1D; create_info.view_type = ._1D_ARRAY;
            case ._2D; create_info.view_type = ._2D_ARRAY;
            case; assert(false);
        }
    }

    return rhi_image_view_create(create_info);
}

rhi_image_view_destroy :: (image_view: RHIImageView) {
    vkDestroyImageView(device, image_view.handle, null);
}

rhi_buffer_destroy :: (buffer: RHIBuffer) {
    vmaDestroyBuffer(vma, buffer.handle, buffer.alloc);
}

rhi_image_destroy :: (image: RHIImage) {
    vmaDestroyImage(vma, image.handle, image.alloc);
}

rhi_buffer_view_create :: (create_info: RHIBufferViewCreateInfo) -> *RHIBufferView {
    assert(create_info.buffer != null);

    vk_create_info := VkBufferViewCreateInfo.{
        buffer = create_info.buffer.handle,
        format = rhi_translate(create_info.format),
        offset = create_info.offset,
        range = create_info.range,
    };

    view: VkBufferView;
    vk_check_result(vkCreateBufferView(device, *vk_create_info, null, *view));

    // #todo: allocate from a pool
    result: *RHIBufferView = alloc(size_of(RHIBufferView));
    (<< result) = .{handle = view, desc = create_info};
    return result;
}

rhi_buffer_view_destroy :: (buffer_view: RHIBufferView) {
    vkDestroyBufferView(device, buffer_view.handle, null);
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