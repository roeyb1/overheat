#scope_export

RHICmdPool :: struct {
    handle: VkCommandPool;
}

RHICmdList :: struct {
    handle: VkCommandBuffer;
}

rhi_cmd_pool_create :: (queue: RHIQueue) -> RHICmdPool {
    create_info := VkCommandPoolCreateInfo.{
        flags = .TRANSIENT_BIT,
        queueFamilyIndex = queue.queue_family_index,
    };

    result: VkCommandPool;
    vk_check_result(vkCreateCommandPool(device, *create_info, null, *result));
    return .{handle = result};
}

rhi_cmd_pool_destroy :: (cmd_pool: RHICmdPool) {
    vkDestroyCommandPool(device, cmd_pool.handle, null);
}

rhi_cmd_pool_reset :: (cmd_pool: RHICmdPool) {
    vkResetCommandPool(device, cmd_pool.handle, 0);
}

rhi_cmd_list_allocate :: (cmd_pool: RHICmdPool) -> RHICmdList {
    result: VkCommandBuffer;

    alloc_info := VkCommandBufferAllocateInfo.{
        commandPool = cmd_pool.handle,
        commandBufferCount = 1,
        level = .PRIMARY,
    };

    vkAllocateCommandBuffers(device, *alloc_info, *result);

    return .{handle = result};
}

rhi_cmd_list_free :: (cmd_pool: RHICmdPool, cmd_list: RHICmdList) {
    vkFreeCommandBuffers(device, cmd_pool.handle, 1, *cmd_list.handle);
}

rhi_cmd_list_begin :: (cmd_list: *RHICmdList) {
    begin_info := VkCommandBufferBeginInfo.{
        flags = .ONE_TIME_SUBMIT_BIT,
    };

    vkBeginCommandBuffer(cmd_list.handle, *begin_info);
}

rhi_cmd_list_end :: (cmd_list: *RHICmdList) {
    vkEndCommandBuffer(cmd_list.handle);
}

rhi_cmd_debug_label_insert :: (cmd_list: *RHICmdList, label: string) {
    debug_label:= VkDebugUtilsLabelEXT.{
        pLabelName = temp_c_string(label),
    };

    vkCmdInsertDebugUtilsLabelEXT(cmd_list.handle, *debug_label);
}

rhi_cmd_debug_label_begin :: (cmd_list: *RHICmdList, label: string) {
    debug_label:= VkDebugUtilsLabelEXT.{
        pLabelName = temp_c_string(label),
    };

    vkCmdBeginDebugUtilsLabelEXT(cmd_list.handle, *debug_label);
}

rhi_cmd_debug_label_end :: (cmd_list: *RHICmdList) {
    vkCmdEndDebugUtilsLabelEXT(cmd_list.handle);
}

rhi_cmd_barrier :: (cmd_list: *RHICmdList, barriers: [] RHIBarrier) {
    push_allocator(temp);

    image_barrier_count: u32 = 0;
    buffer_barrier_count: u32 = 0;

    image_barriers: [..] VkImageMemoryBarrier;
    buffer_barriers: [..] VkBufferMemoryBarrier;
    array_resize(*image_barriers, barriers.count);
    array_resize(*buffer_barriers, barriers.count);

    memory_barrier: VkMemoryBarrier;
    src_stages := VkPipelineStageFlags.TOP_OF_PIPE_BIT;
    dst_stages := VkPipelineStageFlags.BOTTOM_OF_PIPE_BIT;

    for *barrier: barriers {
        // only one of the two should ever be set:
        assert((barrier.image != null) ^ (barrier.buffer != null));

        if (barrier.flags & RHIBarrierFlags.BARRIER_BEGIN) != 0 {
            continue;
        }

        image_format := ifx barrier.image then barrier.image.desc.format else RHIFormat.UNDEFINED;

        before_state_info := rhi_get_resource_state_info(barrier.state_before, rhi_translate(barrier.stages_before), barrier.image != null, image_format);
        after_state_info  := rhi_get_resource_state_info(barrier.state_after, rhi_translate(barrier.stages_after), barrier.image != null, image_format);

        should_acquire_queue := (barrier.flags & RHIBarrierFlags.QUEUE_OWNERSHIP_ACQUIRE) != 0;
        should_release_queue := (barrier.flags & RHIBarrierFlags.QUEUE_OWNERSHIP_RELEASE) != 0;

        requires_image_barrier := barrier.image && (before_state_info.layout != after_state_info.layout || should_acquire_queue || should_release_queue);
        requires_buffer_barrier := barrier.buffer && (should_acquire_queue || should_release_queue);
        requires_memory_barrier := before_state_info.has_write_access && !requires_image_barrier && !requires_buffer_barrier;
        requires_execution_barrier := before_state_info.has_write_access || after_state_info.has_write_access || requires_memory_barrier || requires_buffer_barrier || requires_image_barrier;

        src_queue := barrier.src_queue;
        dst_queue := barrier.dst_queue;

        if requires_image_barrier {
            subresource_range := *barrier.image_subresource_range;
            image_aspect_mask := rhi_image_aspect_mask(rhi_translate(barrier.image.desc.format));

            image_barrier := *image_barriers[image_barrier_count];
            image_barrier_count += 1;

            image_barrier.srcAccessMask = ifx should_acquire_queue then 0 else before_state_info.access_mask;
            image_barrier.dstAccessMask = ifx should_release_queue then 0 else after_state_info.access_mask;
            image_barrier.oldLayout = before_state_info.layout;
            image_barrier.newLayout = after_state_info.layout;
            image_barrier.srcQueueFamilyIndex = ifx barrier.src_queue then src_queue.queue_family_index else VK_QUEUE_FAMILY_IGNORED;
            image_barrier.dstQueueFamilyIndex = ifx barrier.dst_queue then dst_queue.queue_family_index else VK_QUEUE_FAMILY_IGNORED;
            image_barrier.image = barrier.image.handle;
            image_barrier.subresourceRange = VkImageSubresourceRange.{
                aspectMask = image_aspect_mask,
                baseMipLevel = subresource_range.base_mip_level,
                levelCount = subresource_range.level_count,
                baseArrayLayer = subresource_range.base_array_layer,
                layerCount = subresource_range.layer_count,
            };
        } else if requires_buffer_barrier {
            buffer_barrier := *buffer_barriers[buffer_barrier_count];
            buffer_barrier_count += 1;

            buffer_barrier.srcAccessMask = ifx should_acquire_queue then 0 else before_state_info.access_mask;
            buffer_barrier.dstAccessMask = ifx should_release_queue then 0 else after_state_info.access_mask;
            buffer_barrier.srcQueueFamilyIndex = ifx barrier.src_queue then src_queue.queue_family_index else VK_QUEUE_FAMILY_IGNORED;
            buffer_barrier.dstQueueFamilyIndex = ifx barrier.dst_queue then dst_queue.queue_family_index else VK_QUEUE_FAMILY_IGNORED;
            buffer_barrier.buffer = barrier.buffer.handle;
            buffer_barrier.offset = 0;
            buffer_barrier.size = VK_WHOLE_SIZE;
        }

        if requires_memory_barrier {
            memory_barrier.srcAccessMask = before_state_info.access_mask;
            memory_barrier.dstAccessMask = after_state_info.access_mask;
        }
        
        if requires_execution_barrier {
            src_stages |= ifx should_acquire_queue then .TOP_OF_PIPE_BIT else before_state_info.stage_mask;
            dst_stages |= ifx should_release_queue then .BOTTOM_OF_PIPE_BIT else after_state_info.stage_mask;
        }
    }

    if buffer_barrier_count || image_barrier_count || memory_barrier.srcAccessMask || src_stages != .TOP_OF_PIPE_BIT || dst_stages != .BOTTOM_OF_PIPE_BIT {
        vkCmdPipelineBarrier(cmd_list.handle, src_stages, dst_stages, 0, 1, *memory_barrier, buffer_barrier_count, buffer_barriers.data, image_barrier_count, image_barriers.data);
    }
}