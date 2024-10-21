#scope_export

rhi_cmd_debug_label_insert :: (cmd_list: *RHICmdList, label: string) {
    #if VULKAN_DEBUG {
        debug_label:= VkDebugUtilsLabelEXT.{
            pLabelName = temp_c_string(label),
        };

        vkCmdInsertDebugUtilsLabelEXT(cmd_list.handle, *debug_label);
    }
}

rhi_cmd_debug_label_begin :: (cmd_list: *RHICmdList, label: string) {
    #if VULKAN_DEBUG {
        debug_label:= VkDebugUtilsLabelEXT.{
            pLabelName = temp_c_string(label),
        };

        vkCmdBeginDebugUtilsLabelEXT(cmd_list.handle, *debug_label);
    }
}

rhi_cmd_debug_label_end :: (cmd_list: *RHICmdList) {
    #if VULKAN_DEBUG {
        vkCmdEndDebugUtilsLabelEXT(cmd_list.handle);
    }
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

rhi_cmd_copy_buffer :: (cmd_list: *RHICmdList, src: *RHIBuffer, dst: *RHIBuffer, regions: [] RHIBufferCopy) {
    vkCmdCopyBuffer(cmd_list.handle, src.handle, dst.handle, xx regions.count, cast(*VkBufferCopy)regions.data);
}

rhi_cmd_copy_image :: (cmd_list: *RHICmdList, src: *RHIImage, dst: *RHIImage, regions: [] RHIImageCopy) {
    src_handle: VkImage = src.handle;
    dst_handle: VkImage = dst.handle;

    src_aspect_mask := rhi_image_aspect_mask(rhi_translate(src.desc.format));
    dst_aspect_mask := rhi_image_aspect_mask(rhi_translate(dst.desc.format));

    push_allocator(temp);

    vk_regions: [..] VkImageCopy;
    array_resize(*vk_regions, regions.count);
    for 0..regions.count-1 {
        vk_regions[it] = VkImageCopy.{
            .{ src_aspect_mask, regions[it].src_mip_level, regions[it].src_base_layer, regions[it].src_layer_count },
            rhi_translate(regions[it].src_offset),
            .{ dst_aspect_mask, regions[it].dst_mip_level, regions[it].dst_base_layer, regions[it].dst_layer_count },
            rhi_translate(regions[it].dst_offset),
            rhi_translate(regions[it].extent)
        };
    }

    vkCmdCopyImage(cmd_list.handle, src_handle, .TRANSFER_SRC_OPTIMAL, dst_handle, .TRANSFER_DST_OPTIMAL, xx vk_regions.count, vk_regions.data);
}

rhi_cmd_copy_buffer_to_image :: (cmd_list: *RHICmdList, buffer: *RHIBuffer, image: *RHIImage, regions: [] RHIBufferImageCopy) {
    vk_regions: [..] VkBufferImageCopy;
    vk_regions.allocator = temp;
    array_reserve(*vk_regions, regions.count);

    dst_aspect_mask := rhi_image_aspect_mask(rhi_translate(image.desc.format));

    for *region : regions {
        array_add(*vk_regions, VkBufferImageCopy.{
            bufferOffset = xx region.buffer_offset,
            bufferRowLength = region.buffer_row_length,
            bufferImageHeight = region.buffer_image_height,
            imageSubresource = .{dst_aspect_mask, region.image_mip_level, region.image_base_layer, region.image_layer_count},
            imageOffset = cast, force(VkOffset3D) region.offset,
            imageExtent = cast, force(VkExtent3D) region.extent,
        });
    }

    vkCmdCopyBufferToImage(cmd_list.handle, buffer.handle, image.handle, .TRANSFER_DST_OPTIMAL, xx regions.count, vk_regions.data);
}

rhi_cmd_clear_image :: (cmd_list: *RHICmdList, image: *RHIImage, color: RHIClearColorValue, ranges: [] RHIImageSubresourceRange) {
    handle := image.handle;

    push_allocator(temp);
    vk_ranges: [..] VkImageSubresourceRange;

    for *range : ranges {
        vk_range := VkImageSubresourceRange.{ .COLOR_BIT, range.base_mip_level, range.level_count, range.base_array_layer, range.layer_count };
        array_add(*vk_ranges, vk_range);
    }

    vkCmdClearColorImage(cmd_list.handle, handle, .TRANSFER_DST_OPTIMAL, cast(*VkClearColorValue) (*color), xx vk_ranges.count, vk_ranges.data);
}

rhi_cmd_begin_renderpass :: (cmd_list: *RHICmdList, color_attachments: [] RHIColorAttachmentDesc, depth_stencil_attachment: *RHIDepthStencilAttachmentDesc, render_area: RHIRect, rw_texture_buffer_access: bool) {
    assert(color_attachments.count <= 8);

    if rhi_is_dynamic_rendering_ext_supported() {
        vk_color_attachments: [..] VkRenderingAttachmentInfoKHR;
        vk_color_attachments.allocator = temp;
        array_reserve(*vk_color_attachments, 8);

        for attach : color_attachments {
            vk_attachment := VkRenderingAttachmentInfoKHR.{
                imageView = attach.image_view.handle,
                imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
                resolveMode = .NONE,
                //resolveImageView ignored due to resolve mode NONE
                //resolveImageLayout ignroed due to resolve mode NONE
                loadOp = rhi_translate(attach.load_op),
                storeOp = rhi_translate(attach.store_op),
                clearValue.color = cast, force(VkClearColorValue) attach.clear_value,
            };

            array_add(*vk_color_attachments, vk_attachment);
        }

        vk_depth_attach: VkRenderingAttachmentInfo;
        vk_stencil_attach: VkRenderingAttachmentInfo;
        if depth_stencil_attachment {
            vk_depth_attach.imageView = depth_stencil_attachment.image_view.handle;
            vk_depth_attach.imageLayout = ifx depth_stencil_attachment.read_only then .DEPTH_STENCIL_READ_ONLY_OPTIMAL else .DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
            vk_depth_attach.resolveMode = .NONE;
            vk_depth_attach.loadOp = rhi_translate(depth_stencil_attachment.load_op);
            vk_depth_attach.storeOp = rhi_translate(depth_stencil_attachment.store_op);
            vk_depth_attach.clearValue.depthStencil = cast, force(VkClearDepthStencilValue) depth_stencil_attachment.clear_value;

            if rhi_is_stencil_format(depth_stencil_attachment.image_view.desc.format) {
                vk_stencil_attach = vk_depth_attach;
                vk_stencil_attach.loadOp = rhi_translate(depth_stencil_attachment.stencil_load_op);
                vk_stencil_attach.storeOp = rhi_translate(depth_stencil_attachment.stencil_store_op);
            }
        }

        vk_rendering_info := VkRenderingInfoKHR.{
            renderArea = cast, force(VkRect2D) render_area,
            layerCount = 1,
            viewMask = 0,
            colorAttachmentCount = xx vk_color_attachments.count,
            pColorAttachments = vk_color_attachments.data,
            pDepthAttachment = ifx depth_stencil_attachment != null then *vk_depth_attach else null,
            pStencilAttachment = ifx depth_stencil_attachment != null then *vk_stencil_attach else null,
        };

        vkCmdBeginRenderingKHR(cmd_list.handle, *vk_rendering_info);
    } else {
        assert(false); //nyi
    }
}

rhi_cmd_end_renderpass :: (cmd_list: *RHICmdList) {
    if rhi_is_dynamic_rendering_ext_supported() {
        vkCmdEndRenderingKHR(cmd_list.handle);
    } else {
        vkCmdEndRenderPass(cmd_list.handle);
    }
}

rhi_cmd_set_viewport :: (cmd_list: *RHICmdList, first: u32, viewports: [] RHIViewport) {
    vkCmdSetViewport(cmd_list.handle, first, xx viewports.count, xx viewports.data);
}

rhi_cmd_set_scissor :: (cmd_list: *RHICmdList, first: u32, scissors: [] RHIRect) {
    vkCmdSetScissor(cmd_list.handle, first, xx scissors.count, xx scissors.data);
}

rhi_cmd_bind_pipeline :: (cmd_list: *RHICmdList, pipeline: RHIGraphicsPipeline) {
    vkCmdBindPipeline(cmd_list.handle, .GRAPHICS, pipeline.pipeline);

    rhi_bind_static_sampler_set(cmd_list, pipeline);
}

rhi_cmd_bind_pipeline :: (cmd_list: *RHICmdList, pipeline: RHIComputePipeline) {
    vkCmdBindPipeline(cmd_list.handle, .COMPUTE, pipeline.pipeline);

    rhi_bind_static_sampler_set(cmd_list, pipeline);
}

rhi_cmd_bind_descriptor_sets :: (cmd_list: *RHICmdList, pipeline: RHIGraphicsPipeline, first: u32, sets: [] RHIDescriptorSet, offsets: [] u32) {
    vk_sets: [..] VkDescriptorSet;
    vk_sets.allocator = temp;
    array_reserve(*vk_sets, sets.count);
    for *set : sets {
        array_add(*vk_sets, set.handle);
    }

    vkCmdBindDescriptorSets(cmd_list.handle, .GRAPHICS, pipeline.pipeline_layout, first, xx vk_sets.count, vk_sets.data, xx offsets.count, offsets.data);
}

rhi_cmd_bind_descriptor_sets :: (cmd_list: *RHICmdList, pipeline: RHIComputePipeline, first: u32, sets: [] RHIDescriptorSet, offsets: [] u32) {
    vk_sets: [..] VkDescriptorSet;
    vk_sets.allocator = temp;
    array_reserve(*vk_sets, sets.count);
    for *set : sets {
        array_add(*vk_sets, set.handle);
    }

    vkCmdBindDescriptorSets(cmd_list.handle, .COMPUTE, pipeline.pipeline_layout, first, xx vk_sets.count, vk_sets.data, xx offsets.count, offsets.data);
}

rhi_bind_static_sampler_set :: (cmd_list: *RHICmdList, pipeline: RHIPipeline) {
    if pipeline.static_sampler_descriptor_set != VK_NULL_HANDLE {
        vkCmdBindDescriptorSets(cmd_list.handle, .GRAPHICS, pipeline.pipeline_layout, xx pipeline.static_sampler_descriptor_set_index, 1, *pipeline.static_sampler_descriptor_set, 0, null);
    }
}

rhi_cmd_bind_vertex_buffers :: (cmd_list: *RHICmdList, first: u32, buffers: [] *RHIBuffer, offsets: [] u64) {
    vk_buffers: [..] VkBuffer;
    vk_buffers.allocator = temp;
    array_reserve(*vk_buffers, buffers.count);

    for buffer : buffers {
        array_add(*vk_buffers, buffer.handle);
    }

    vkCmdBindVertexBuffers(cmd_list.handle, first, xx vk_buffers.count, vk_buffers.data, offsets.data);
}

rhi_cmd_bind_index_buffer :: (cmd_list: *RHICmdList, buffer: *RHIBuffer, offset: u64, type: RHIIndexType) {
    vkCmdBindIndexBuffer(cmd_list.handle, buffer.handle, offset, rhi_translate(type));
}

rhi_cmd_draw :: (cmd_list: *RHICmdList, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) {
    vkCmdDraw(cmd_list.handle, vertex_count, instance_count, first_vertex, first_instance);
}

rhi_cmd_draw_indexed :: (cmd_list: *RHICmdList, index_count: u32, instance_count: u32, first_index: u32, vertex_offset: s32, first_instance: u32) {
    vkCmdDrawIndexed(cmd_list.handle, index_count, instance_count, first_index, vertex_offset, first_instance);
}

rhi_cmd_push_constants :: (cmd_list: *RHICmdList, pipeline: RHIPipeline, stage_flags: RHIShaderStageFlags, offset: u32, size: u32, data: *void) {
    vkCmdPushConstants(cmd_list.handle, pipeline.pipeline_layout, rhi_translate(stage_flags), offset, size, data);
}

rhi_cmd_dispatch :: (cmd_list: *RHICmdList, group_count_x: u32, group_count_y: u32, group_count_z: u32) {
    vkCmdDispatch(cmd_list.handle, group_count_x, group_count_y, group_count_z);
}
