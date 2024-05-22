#scope_export

RDGPassFunction :: #type (cmd_list: *RHICmdList, pass_data: *void) -> ();

RDGResourceHandle      :: u32;
RDGResourceViewHandle  :: u32;

RDG_NULL_HANDLE: RDGResourceHandle : 0;

RDGImageDescription :: struct {
    debug_name: string = "";

    width: u32 = 1;
    height: u32 = 1;
    depth: u32 = 1;
    layers: u32 = 1;
    levels: u32 = 1;

    samples := RHISampleCount._1;
    image_type := RHIImageType._2D;
    format := RHIFormat.UNDEFINED;
    usage_flags: RHIImageUsageFlags;
    clear_value: RHIClearValue;
}

RDGImageViewDescription :: struct {
    debug_name: string;

    image_handle: RDGResourceHandle;
    subresource_range: RHIImageSubresourceRange;
    view_type: RHIImageViewType;
    format: RHIFormat;
    components: RHIComponentMapping;
}

RDGBufferDescription :: struct {
    debug_name: string;

    size: u64;
    usage: RHIBufferUsageFlags = 0;
    host_visible: bool = false;
}

RDGBufferViewDescription :: struct {
    debug_name: string;

    buffer_handle: RDGResourceHandle;
    
    offset: u64;
    range: u64;
    byte_stride: u32;
    format: RHIFormat;
}

RDGResourceDescription :: struct {
    debug_name: string = "";

    usage_flags: u32;
    width: u32 = 1;
    height: u32 = 1;
    depth: u32 = 1;
    layers: u32 = 1;
    levels: u32 = 1;

    samples := RHISampleCount._1;
    image_type := RHIImageType._2D;
    format := RHIFormat.UNDEFINED;
    image_flags: RHIImageFlags;
    clear_value: RHIClearValue;

    offset: u64 = 0;
    size: u64 = 0;

    subresource_count: u32 = 1;
    subresource_usage_offset: u32 = 0;

    external_state_data: *RDGResourceStateData;

    is_image := false;
    is_external := false;
    is_concurrent := false;
    host_visible: bool;
}

RDGResourceViewDescription :: struct {
    debug_name: string = "";
    resource_handle: RDGResourceHandle;
    view_type: RHIImageViewType;
    format: RHIFormat;
    components: RHIComponentMapping;
    subresource_range: RHIImageSubresourceRange;
    offset: u64;
    range: u64;
    structure_byte_stride: u32;
    is_image: bool;
}

RDGResource :: struct {
    image: *RHIImage;
    buffer: *RHIBuffer;
    is_external: bool;
}

RDGResourceView :: struct {
    image_view: *RHIImageView;
    buffer_view: *RHIBufferView;
    texture_handle: RDGTextureViewHandle;
    rw_texture_handle: RDGRWTextureViewHandle;
    typed_buffer_handle: RDGTypedBufferViewHandle;
    rw_typed_buffer_handle: RDGRWTypedBufferViewHandle;
    byte_buffer_handle: RDGByteBufferViewHandle;
    rw_byte_buffer_handle: RDGRWByteBufferViewHandle;
    structured_buffer_handle: RDGStructuredBufferViewHandle;
    rw_structured_buffer_handle: RDGRWStructuredBufferViewHandle;
}

RDGResourceStateAndStage :: struct {
    resource_state := RHIResourceState.UNDEFINED;
    stage_mask := RHIPipelineStageFlags.TOP_OF_PIPE_BIT;
}

RDGResourceStateData :: struct {
    state_and_stage: RDGResourceStateAndStage;
    queue: *RHIQueue;
}

RDGResourceUsageDesc :: struct {
    view_handle: RDGResourceViewHandle;
    state_and_stage: RDGResourceStateAndStage = .{};
    final_state_and_stage: RDGResourceStateAndStage = .{}; // defaulted if pass does no internal state transitions
}

RDGSubresourceUsage :: struct {
    pass_handle: u16;
    initial_state: RDGResourceStateAndStage;
    final_state: RDGResourceStateAndStage;
}

RDGPassData :: struct {
    debug_name: string;

    pass_func: RDGPassFunction;
    user_data: *void;

    queue: *RHIQueue;
    signal_value: u64;
    before_barriers: [..] RHIBarrier;
    after_barriers: [..] RHIBarrier;
}

RDGBatch :: struct {
    queue: *RHIQueue;
    pass_index_offset: u16;
    pass_index_count: u16;
    wait_dst_stage_masks: [3] RHIPipelineStageFlags;
    wait_values: [3] u64;
    signal_value: u64;
}

RDGFrameCmdPools :: struct {
    cmd_pools: [RHI_QUEUE_COUNT] RHICmdPool;
    cmd_lists: [RHI_QUEUE_COUNT][..] RHICmdList;
    next_free_index: [RHI_QUEUE_COUNT] u32;
}

RDGPerFrameGPUResources :: struct {
    resources: [..] RDGResource;
    views: [..] RDGResourceView;
    frame_cmd_pools: RDGFrameCmdPools;
    final_wait_values: [3] u64;
}

RDG_NUM_FRAMES :: 2;

RenderGraph :: struct {
    frame_number: u64 = 0;

    semaphores: [RHI_QUEUE_COUNT] RHISemaphore;
    semaphore_values: [RHI_QUEUE_COUNT] u64;

    resource_descs: [..] RDGResourceDescription;
    view_descs: [..] RDGResourceViewDescription;
    culled_resources: Bit_Array;
    subresource_usages: [..][..] RDGSubresourceUsage; // usages[subresource_index][usage_index];

    passes: [..] RDGPassData;
    batches: [..] RDGBatch;
    external_release_barriers: [RHI_QUEUE_COUNT][..] RHIBarrier;

    per_frame_resources: [RHI_QUEUE_COUNT] RDGPerFrameGPUResources;
}

g_render_graph: RenderGraph;

rdg_initialize :: (rg: *RenderGraph) {
    rg.semaphores[RHIQueueIndex.GRAPHICS] = rhi_semaphore_create(0, "Graphics Queue Semaphore");
    rg.semaphores[RHIQueueIndex.COMPUTE] = rhi_semaphore_create(0, "Compute Queue Semaphore");
    rg.semaphores[RHIQueueIndex.TRANSFER] = rhi_semaphore_create(0, "Transfer Queue Semaphore");
    for 0..rg.semaphore_values.count-1 {
        rg.semaphore_values[it] = 0;
    }
}

rdg_shutdown :: (rg: *RenderGraph) {
    for 0..RDG_NUM_FRAMES-1 {
        rdg_next_frame(rg);
    }

    for 0..RDG_NUM_FRAMES-1 {
        for *cmd_pool : rg.per_frame_resources[it].frame_cmd_pools.cmd_pools {
            rhi_cmd_pool_destroy(cmd_pool);
        }
        array_free(rg.per_frame_resources[it].resources);
        array_free(rg.per_frame_resources[it].views);
    }

    for 0..RHI_QUEUE_COUNT-1 {
        rhi_semaphore_destroy(rg.semaphores[it]);
    }
}

rdg_next_frame :: (rg: *RenderGraph) -> u64 {
    rg.frame_number += 1;

    // wait on semaphore and clean up old frame resources once it completes: 
    {
        frame_resources := *rg.per_frame_resources[rg.frame_number % RDG_NUM_FRAMES];

        for 0..rg.semaphores.count-1 {
            rhi_semaphore_wait(rg.semaphores[it], rg.semaphore_values[it]);
        }
        
        for *res : frame_resources.resources {
            if res.is_external {
                continue;
            }

            if res.image {
                rhi_image_destroy(res.image);
            } else if res.buffer {
                rhi_buffer_destroy(res.buffer);
            }
        }
        array_reset_keeping_memory(*frame_resources.resources);

        for *view : frame_resources.views {
            if view.image_view {
                rhi_image_view_destroy(view.image_view);
            } else if view.buffer_view {
                rhi_buffer_view_destroy(view.buffer_view);
            }
        }
        array_reset_keeping_memory(*frame_resources.views);

        rdg_frame_cmd_pool_reset(*frame_resources.frame_cmd_pools);
    }

    // clear data without freeing memory so we can reuse capacity later:
    array_reset_keeping_memory(*rg.resource_descs);
    array_reset_keeping_memory(*rg.view_descs);
    for rg.subresource_usages {
        array_free(rg.subresource_usages[it_index]);
    }
    array_reset_keeping_memory(*rg.subresource_usages);
    array_reset_keeping_memory(*rg.passes);
    array_reset_keeping_memory(*rg.batches);
    for rg.external_release_barriers {
        array_reset_keeping_memory(*rg.external_release_barriers[it_index]);
    }
    deinit(*rg.culled_resources);

    return rg.frame_number;
}

rdg_allocate_pass_data :: (rg: *RenderGraph, $type: Type) -> *type {
    // #todo: allocate from a linear allocator that can be freed when graph finishes executing
    return New(type);
}

rdg_free_pass_datas :: (rg: *RenderGraph) {
    for pass : rg.passes {
        free(pass.before_barriers.data);
        free(pass.after_barriers.data);
        free(pass.user_data);
    }
}

rdg_add_pass :: (rg: *RenderGraph, name: string, queue_type: RHIQueueType, usage_descs: [] RDGResourceUsageDesc, user_data: *void, pass_func: RDGPassFunction) {
    pass_data: RDGPassData;
    pass_data.pass_func = pass_func;
    pass_data.debug_name = name;
    pass_data.queue = *rhi_queues[queue_type];
    pass_data.user_data = user_data;

    pass_index := cast (u16) rg.passes.count;
    array_add(*rg.passes, pass_data);
    
    for usage : usage_descs {
        assert(usage.view_handle != 0);

        view_desc := *rg.view_descs[usage.view_handle - 1];
        resource_usage: RDGSubresourceUsage;
        resource_usage.pass_handle = pass_index;
        resource_usage.initial_state = usage.state_and_stage;
        // If undefined, there are no transitions so final is the same:
        if usage.final_state_and_stage.resource_state == RHIResourceState.UNDEFINED {
            resource_usage.final_state = usage.state_and_stage;
        } else {
            resource_usage.final_state = usage.final_state_and_stage;
        }

        resource_index := view_desc.resource_handle - 1;
        resource_desc := *rg.resource_descs[resource_index];
        
        if resource_desc.is_image {
            base_layer := view_desc.subresource_range.base_array_layer;
            layer_count := view_desc.subresource_range.layer_count;
            base_level := view_desc.subresource_range.base_mip_level;
            level_count := view_desc.subresource_range.level_count;

            assert(layer_count > 0 && level_count > 0);

            for layer : 0..layer_count-1 {
                for level : 0..level_count-1 {
                    index := (layer + base_layer) * resource_desc.levels + (level + base_level) + resource_desc.subresource_usage_offset;
                    array_add(*rg.subresource_usages[index], resource_usage);
                }
            }
        } else {
            array_add(*rg.subresource_usages[resource_desc.subresource_usage_offset], resource_usage);
        }
    }
}

rdg_execute :: (rg: *RenderGraph) {
    rdg_create_resources(rg);
    rdg_create_synchronization(rg);

    rdg_flush_resource_view_updates(*g_view_registry);

    rdg_record_and_submit(rg);
}

rdg_create_resources :: (using rg: *RenderGraph) {
    frame_index := frame_number % RDG_NUM_FRAMES;
    frame_resources := *per_frame_resources[frame_index];

    array_resize(*frame_resources.resources, resource_descs.count);
    array_resize(*frame_resources.views, resource_descs.count);

    init_bit_array(*culled_resources, resource_descs.count);

    for *resource_desc : resource_descs {
        // Don't need to create a resource for an external resource
        if resource_desc.is_external {
            continue;
        }

        resource_index := it_index;

        is_referenced := false;
        usage_flags := resource_desc.usage_flags;

        subresource_count := resource_desc.subresource_count;
        for subresource_index : 0..subresource_count-1 {
            subresource_usage_index := subresource_index + resource_desc.subresource_usage_offset;

            is_referenced |= (subresource_usages[subresource_usage_index].count > 0);

            for *usage : subresource_usages[subresource_usage_index] {
                usage_flags |= rhi_usage_flags(usage.initial_state.resource_state, resource_desc.is_image);
                usage_flags |= rhi_usage_flags(usage.final_state.resource_state, resource_desc.is_image);
            }
        }

        if !is_referenced {
            set_bit(*culled_resources, resource_index);
            continue;
        }

        if resource_desc.is_image {
            image_create_info := RHIImageCreateInfo.{
                extent = .{width = resource_desc.width, height = resource_desc.height},
                depth = resource_desc.depth,
                layers = resource_desc.layers,
                levels = resource_desc.levels,
                samples = resource_desc.samples,
                image_type = resource_desc.image_type,
                format = resource_desc.format,
                usage_flags = cast (RHIImageUsageFlags) usage_flags,
                clear_value = resource_desc.clear_value,
            };

            frame_resources.resources[resource_index].image = rhi_image_create(image_create_info, .DEVICE_LOCAL_BIT, 0, false);
            rhi_debug_set_object_name(frame_resources.resources[resource_index].image, resource_desc.debug_name);
        } else {
            buffer_create_info := RHIBufferCreateInfo.{
                size = resource_desc.size,
                create_flags = 0,
                usage_flags = cast (RHIBufferUsageFlags) usage_flags,
            };

            required_flags: RHIMemoryPropertyFlags = ifx resource_desc.host_visible then (.HOST_VISIBLE_BIT | .HOST_COHERENT_BIT) else .DEVICE_LOCAL_BIT;
            preferred_flags: RHIMemoryPropertyFlags = ifx resource_desc.host_visible then .DEVICE_LOCAL_BIT else cast (RHIMemoryPropertyFlags) 0;

            frame_resources.resources[resource_index].buffer = rhi_buffer_create(buffer_create_info, required_flags, preferred_flags, false);
            rhi_debug_set_object_name(frame_resources.resources[resource_index].buffer, resource_desc.debug_name);
        }
    }


    // create views
    for *view_desc : view_descs {
        if culled_resources[view_desc.resource_handle - 1] {
            continue;
        }

        view_data := *frame_resources.views[it_index];
        << view_data = .{};

        if view_desc.is_image {
            view_create_info := RHIImageViewCreateInfo.{
                image = frame_resources.resources[view_desc.resource_handle - 1].image,
                view_type = view_desc.view_type,
                format = view_desc.format,
                base_mip_level = view_desc.subresource_range.base_mip_level,
                level_count = view_desc.subresource_range.level_count,
                base_array_layer = view_desc.subresource_range.base_array_layer,
                layer_count = view_desc.subresource_range.layer_count,
            };

            view_data.image_view = rhi_image_view_create(view_create_info);
            rhi_debug_set_object_name(view_data.image_view, view_desc.debug_name);

            usage_flags := view_create_info.image.desc.usage_flags;

            if (usage_flags & RHIImageUsageFlags.TEXTURE_BIT) != 0 {
                view_data.texture_handle = rdg_create_texture_view_handle(*g_view_registry, view_data.image_view, true);
            }
            if (usage_flags & RHIImageUsageFlags.RW_TEXTURE_BIT) != 0 {
                view_data.rw_texture_handle = rdg_create_rw_texture_view_handle(*g_view_registry, view_data.image_view, true);
            }
        } else if view_desc.format != RHIFormat.UNDEFINED {
            view_create_info := RHIBufferViewCreateInfo.{
                buffer = frame_resources.resources[view_desc.resource_handle - 1].buffer,
                format = view_desc.format,
                offset = view_desc.offset,
                range = view_desc.range,
            };

            view_data.buffer_view = rhi_buffer_view_create(view_create_info);
            rhi_debug_set_object_name(view_data.buffer_view, view_desc.debug_name);
        }

        if !view_desc.is_image {
            buffer: *RHIBuffer = frame_resources.resources[view_desc.resource_handle - 1].buffer;
            usage_flags := buffer.desc.usage_flags;
            resource_desc := *resource_descs[view_desc.resource_handle - 1];

            buffer_info := RHIDescriptorBufferInfo.{
                buffer = buffer,
                offset = resource_desc.offset + view_desc.offset,
                range = view_desc.range,
                structure_byte_stride = view_desc.structure_byte_stride,
            };

            if (usage_flags & RHIBufferUsageFlags.TYPED_BUFFER_BIT) != 0 && view_data.buffer_view {
                view_data.typed_buffer_handle = rdg_create_typed_buffer_view_handle(*g_view_registry, view_data.buffer_view, true);
            }
            if (usage_flags & RHIBufferUsageFlags.RW_TYPED_BUFFER_BIT) != 0 && view_data.buffer_view {
                view_data.rw_typed_buffer_handle = rdg_create_rw_typed_buffer_view_handle(*g_view_registry, view_data.buffer_view, true);
            }
            if (usage_flags & RHIBufferUsageFlags.BYTE_BUFFER_BIT) != 0 {
                view_data.byte_buffer_handle = rdg_create_byte_buffer_view_handle(*g_view_registry, buffer_info, true);
            }
            if (usage_flags & RHIBufferUsageFlags.RW_BYTE_BUFFER_BIT) != 0 {
                view_data.rw_byte_buffer_handle = rdg_create_rw_byte_buffer_view_handle(*g_view_registry, buffer_info, true);
            }
            if view_desc.structure_byte_stride != 0 && ((usage_flags & RHIBufferUsageFlags.STRUCTURED_BUFFER_BIT) != 0) {
                view_data.structured_buffer_handle = rdg_create_structured_buffer_view_handle(*g_view_registry, buffer_info, true);
            }
            if view_desc.structure_byte_stride != 0 && ((usage_flags & RHIBufferUsageFlags.RW_STRUCTURED_BUFFER_BIT) != 0) {
                view_data.rw_structured_buffer_handle = rdg_create_rw_structured_buffer_view_handle(*g_view_registry, buffer_info, true);
            }
        }
    }
}

rdg_create_synchronization :: (rg: *RenderGraph) {

    SemaphoreDependencyInfo :: struct {
        wait_dst_stage_masks: [RHI_QUEUE_COUNT] RHIPipelineStageFlags;
        wait_values: [RHI_QUEUE_COUNT] u64;
    }

    UsageInfo :: struct {
        pass_handle: u16;
        queue: *RHIQueue;
        state_and_stage: RDGResourceStateAndStage;
    }

    frame_resources := *rg.per_frame_resources[rg.frame_number % RDG_NUM_FRAMES];

    semaphore_deps: [..] SemaphoreDependencyInfo;
    semaphore_deps.allocator = temp;
    array_resize(*semaphore_deps, rg.passes.count);

    for res_idx : 0..rg.resource_descs.count-1 {
        if rg.culled_resources[res_idx] {
            continue;
        }

        res_desc := *rg.resource_descs[res_idx];

        for subresource_idx : 0..res_desc.subresource_count-1 {
            subresource_usage_idx := subresource_idx + res_desc.subresource_usage_offset;
            
            if rg.subresource_usages[subresource_usage_idx].count == 0 {
                continue;
            }

            prev_usage_info: UsageInfo;
            prev_usage_info.queue = rg.passes[rg.subresource_usages[subresource_usage_idx][0].pass_handle].queue;

            if res_desc.is_external {
                ext_info := res_desc.external_state_data;
                if ext_info {
                    prev_usage_info.queue = ext_info[subresource_idx].queue;
                    prev_usage_info.state_and_stage = ext_info[subresource_idx].state_and_stage;
                } else {
                    prev_usage_info.queue = prev_usage_info.queue;
                    prev_usage_info.state_and_stage = prev_usage_info.state_and_stage;
                }
                prev_usage_info.pass_handle = cast(u16) rhi_queue_index(prev_usage_info.queue);
                
                if ext_info {
                    last_usage := *rg.subresource_usages[subresource_usage_idx][rg.subresource_usages[subresource_usage_idx].count -1];
                    ext_info[subresource_idx].queue = rg.passes[last_usage.pass_handle].queue;
                    ext_info[subresource_idx].state_and_stage = last_usage.final_state;
                }
            }

            usage_count := rg.subresource_usages[subresource_usage_idx].count;
            usage_idx := 0;
            while usage_idx < usage_count {
                subres_usage := *rg.subresource_usages[subresource_usage_idx][usage_idx];
                pass_data := *rg.passes[subres_usage.pass_handle];

                curr_usage_info := UsageInfo.{
                    subres_usage.pass_handle,
                    pass_data.queue,
                    subres_usage.initial_state,
                };

                next_usage_idx := usage_idx + 1;

                combinable_image_read_states: RHIResourceState = .READ_RESOURCE | .READ_DEPTH_STENCIL;
                combinable_buffer_read_states: RHIResourceState = .READ_RESOURCE | .READ_CONSTANT_BUFFER | .READ_VERTEX_BUFFER | .READ_INDEX_BUFFER | .READ_INDIRECT_BUFFER | .READ_TRANSFER;

                has_no_custom_final_state := curr_usage_info.state_and_stage.resource_state == subres_usage.final_state.resource_state && curr_usage_info.state_and_stage.stage_mask == subres_usage.final_state.stage_mask;

                if has_no_custom_final_state && 
                    (res_desc.is_image && (curr_usage_info.state_and_stage.resource_state & combinable_image_read_states) != 0 ||
                    !res_desc.is_image && (curr_usage_info.state_and_stage.resource_state & combinable_buffer_read_states) != 0)
                {
                    while next_usage_idx < usage_count {
                        next_subres_usage := *rg.subresource_usages[subresource_usage_idx][next_usage_idx];
                        next_pass_data := *rg.passes[next_subres_usage.pass_handle];

                        next_usage_info := UsageInfo.{
                            next_subres_usage.pass_handle,
                            next_pass_data.queue,
                            next_subres_usage.initial_state,
                        };

                        is_same_queue := next_pass_data.queue == pass_data.queue;

                        no_custom_final_state := next_usage_info.state_and_stage.resource_state == next_subres_usage.final_state.resource_state && next_usage_info.state_and_stage.stage_mask == next_subres_usage.final_state.stage_mask;
                        
                        is_combinable := (res_desc.is_image && (next_usage_info.state_and_stage.resource_state & combinable_image_read_states) != 0) || (!res_desc.is_image && (next_usage_info.state_and_stage.resource_state & combinable_buffer_read_states) != 0);

                        if !is_same_queue || !is_combinable || !no_custom_final_state {
                            break;
                        }

                        curr_usage_info.state_and_stage.stage_mask |= next_usage_info.state_and_stage.stage_mask;
                        curr_usage_info.state_and_stage.resource_state |= next_usage_info.state_and_stage.resource_state;
                        next_usage_idx += 1;
                    }
                }

                barrier := RHIBarrier.{
                    image = ifx res_desc.is_image then frame_resources.resources[res_idx].image else null,
                    buffer = ifx !res_desc.is_image then frame_resources.resources[res_idx].buffer else null,
                    stages_before = prev_usage_info.state_and_stage.stage_mask,
                    state_before = prev_usage_info.state_and_stage.resource_state,
                    stages_after = curr_usage_info.state_and_stage.stage_mask,
                    state_after = curr_usage_info.state_and_stage.resource_state,
                    src_queue = prev_usage_info.queue,
                    dst_queue = curr_usage_info.queue,
                    image_subresource_range = .{ cast(u32) subresource_idx % res_desc.levels, 1, cast(u32) subresource_idx / res_desc.levels, 1},
                };

                if barrier.src_queue != barrier.dst_queue && !res_desc.is_concurrent {
                    barrier.flags |= .QUEUE_OWNERSHIP_ACQUIRE;
                }
                if usage_idx == 0 {
                    barrier.flags |= .FIRST_ACCESS_IN_SUBMISSION;
                }

                if usage_idx > 0 && prev_usage_info.queue == curr_usage_info.queue {
                    actual_prev_pass_handle := rg.subresource_usages[subresource_usage_idx][usage_idx - 1].pass_handle;
                    if (actual_prev_pass_handle + 1) < curr_usage_info.pass_handle {
                        flags := barrier.flags;
                        barrier.flags |= .BARRIER_BEGIN;
                        array_add(*rg.passes[actual_prev_pass_handle + 1].before_barriers, barrier);

                        barrier.flags = flags;
                        barrier.flags |= .BARRIER_END;
                    }
                }

                array_add(*pass_data.before_barriers, barrier);

                prev_queue_idx := rhi_queue_index(prev_usage_info.queue);

                if (barrier.flags & .QUEUE_OWNERSHIP_ACQUIRE) != 0 {
                    barrier.flags ^= .QUEUE_OWNERSHIP_ACQUIRE;
                    barrier.flags |= .QUEUE_OWNERSHIP_RELEASE;

                    semaphore_deps[curr_usage_info.pass_handle].wait_dst_stage_masks[prev_queue_idx] |= curr_usage_info.state_and_stage.stage_mask;

                    wait_value := *semaphore_deps[curr_usage_info.pass_handle].wait_values[prev_queue_idx];

                    //external dep
                    if usage_idx == 0 {
                        array_add(*rg.external_release_barriers[prev_usage_info.pass_handle], barrier);
                        (<< wait_value) = max(rg.semaphore_values[prev_queue_idx] + 1, << wait_value);
                    } else {
                        prev_pass_record_info := *rg.passes[prev_usage_info.pass_handle];
                        array_add(*prev_pass_record_info.after_barriers, barrier);
                        (<< wait_value) = max(rg.semaphore_values[prev_queue_idx] + 1 + prev_pass_record_info.signal_value, << wait_value);
                    }
                }

                prev_usage_info = curr_usage_info;
                if !has_no_custom_final_state {
                    prev_usage_info.state_and_stage = subres_usage.final_state;
                }

                usage_idx = next_usage_idx;
            }
        }
    }

    prev_queue: *RHIQueue = null;
    start_new_batch := false;

    for 0..rg.passes.count-1 {
        pass_handle := it;
        semaphore_dep := *semaphore_deps[pass_handle];
        curr_queue := rg.passes[pass_handle].queue;

        start_new_batch = start_new_batch
            || prev_queue != curr_queue
            || semaphore_dep.wait_dst_stage_masks[0] != 0
            || semaphore_dep.wait_dst_stage_masks[1] != 0
            || semaphore_dep.wait_dst_stage_masks[2] != 0;

        if start_new_batch {
            start_new_batch = false;

            batch := array_add(*rg.batches);
            batch.queue = curr_queue;
            batch.pass_index_offset = cast(u16)pass_handle;

            for j : 0..RHI_QUEUE_COUNT-1 {
                batch.wait_dst_stage_masks[j] = semaphore_dep.wait_dst_stage_masks[j];
                batch.wait_values[j] = semaphore_dep.wait_values[j];
            }
        }

        if !(rg.passes[pass_handle].after_barriers.count == 0) || (it == rg.passes.count - 1) {
            start_new_batch := true;
        }

        batch := *rg.batches[rg.batches.count - 1];
        queue_idx := rhi_queue_index(curr_queue);
        batch.signal_value = max(rg.semaphore_values[queue_idx] + 1 + rg.passes[pass_handle].signal_value, batch.signal_value);

        prev_queue = curr_queue;
        batch.pass_index_count += 1;
    }
}

rdg_record_and_submit :: (rg: *RenderGraph) {
    frame_index := rg.frame_number % RDG_NUM_FRAMES;
    frame_resources := *rg.per_frame_resources[frame_index];
    for 0..frame_resources.final_wait_values.count-1 {
        frame_resources.final_wait_values[it] = rg.semaphore_values[it];
    }

    // Release passes for external resources
    {
        release_pass_names := string.[
            "Release Barrier For External Resources (Graphics)",
            "Release Barrier For External Resources (Compute)",
            "Release Barrier For External Resources (Transfer)",
        ];

        for 0..RHI_QUEUE_COUNT-1 {
            if rg.external_release_barriers[it].count > 0 {
                cmd_list := rdg_frame_cmd_pool_acquire(*frame_resources.frame_cmd_pools, *rhi_queues[it]);

                rhi_cmd_list_begin(cmd_list);
                
                rhi_cmd_debug_label_insert(cmd_list, release_pass_names[it]);
                rhi_cmd_barrier(cmd_list, rg.external_release_barriers[it]);

                rhi_cmd_list_end(cmd_list);

                wait_value := rg.semaphore_values[it];
                signal_value := wait_value + 1;

                wait_dst_stage_mask := RHIPipelineStageFlags.TOP_OF_PIPE_BIT;

                wait_semaphores := *RHISemaphore.[*rg.semaphores[it]];

                submit_info := RHISubmitInfo.{
                    wait_semaphores = wait_semaphores,
                    wait_values = u64.[wait_value],
                    wait_dst_stage_masks = .[wait_dst_stage_mask],
                    command_lists = *RHICmdList.[cmd_list],
                    signal_semaphores = *RHISemaphore.[*rg.semaphores[it]],
                    signal_values = u64.[wait_value],
                };

                rhi_queue_submit(*rhi_queues[it], .[*submit_info]);
                frame_resources.final_wait_values[it] = max(frame_resources.final_wait_values[it], signal_value);
            }
        }
    }

    for *batch : rg.batches {
        cmd_list := rdg_frame_cmd_pool_acquire(*frame_resources.frame_cmd_pools, batch.queue);

        rhi_cmd_list_begin(cmd_list);

        for 0..batch.pass_index_count-1 {
            pass_data := *rg.passes[it + batch.pass_index_offset];
            ZoneScoped(name = pass_data.debug_name);

            if pass_data.debug_name.count > 0 {
                rhi_cmd_debug_label_begin(cmd_list, pass_data.debug_name);
            }

            if pass_data.before_barriers.count > 0 {
                rhi_cmd_barrier(cmd_list, pass_data.before_barriers);
            }

            pass_data.pass_func(cmd_list, pass_data.user_data);

            if pass_data.after_barriers.count > 0 {
                rhi_cmd_barrier(cmd_list, pass_data.after_barriers);
            }
            if pass_data.debug_name.count > 0 {
                rhi_cmd_debug_label_end(cmd_list);
            }
        }
        
        rhi_cmd_list_end(cmd_list);

        // submit to queues;
        {
            wait_semaphores: [RHI_QUEUE_COUNT] *RHISemaphore;
            wait_dst_stage_masks: [RHI_QUEUE_COUNT] RHIPipelineStageFlags;
            wait_values: [RHI_QUEUE_COUNT] u64;
            wait_count: u32 = 0;

            for 0..RHI_QUEUE_COUNT-1 {
                if batch.wait_dst_stage_masks[it] != 0 {
                    wait_semaphores[wait_count] = *rg.semaphores[it];
                    wait_dst_stage_masks[wait_count] = batch.wait_dst_stage_masks[it];
                    wait_values[wait_count] = batch.wait_values[it];
                    wait_count += 1;
                }
            }

            queue_index := rhi_queue_index(batch.queue);

            submit_info := RHISubmitInfo.{
                wait_semaphore_count = wait_count,
                wait_semaphores = wait_semaphores,
                wait_values = wait_values,
                wait_dst_stage_masks = wait_dst_stage_masks,
                command_lists = .[cmd_list],
                signal_semaphores = .[*rg.semaphores[queue_index]],
                signal_values = .[batch.signal_value]
            };

            rhi_queue_submit(batch.queue, .[*submit_info]);

            frame_resources.final_wait_values[queue_index] = max(frame_resources.final_wait_values[queue_index], batch.signal_value);
        }
    }

    for 0..RHI_QUEUE_COUNT-1 {
        rg.semaphore_values[it] = frame_resources.final_wait_values[it];
    }

    // free all user datas
    rdg_free_pass_datas(rg);
}

rdg_frame_cmd_pool_acquire :: (frame_pools: *RDGFrameCmdPools, queue: *RHIQueue) -> *RHICmdList {
    CHUNK_SIZE :: 1;

    pool_index := rhi_queue_index(queue);

    if frame_pools.cmd_pools[pool_index].handle == VK_NULL_HANDLE {
        frame_pools.cmd_pools[pool_index] = rhi_cmd_pool_create(queue);
    }

    current_pool_size := frame_pools.cmd_lists[pool_index].count;
    if frame_pools.next_free_index[pool_index] == current_pool_size {
        array_resize(*frame_pools.cmd_lists[pool_index], current_pool_size + CHUNK_SIZE);

        // #todo: batch cmd list allocations 
        for 0..CHUNK_SIZE-1 {
            frame_pools.cmd_lists[pool_index][current_pool_size + it] = rhi_cmd_list_allocate(frame_pools.cmd_pools[pool_index]);
        }
    }


    frame_pools.next_free_index[pool_index] += 1;
    return *frame_pools.cmd_lists[pool_index][frame_pools.next_free_index[pool_index] - 1];
}

rdg_frame_cmd_pool_reset :: (frame_pools: *RDGFrameCmdPools) {
    for 0..frame_pools.cmd_pools.count-1 {
        if frame_pools.cmd_pools[it].handle != VK_NULL_HANDLE {
            rhi_cmd_pool_reset(frame_pools.cmd_pools[it]);
        }
        frame_pools.next_free_index[it] = 0;
    }
}

#import "Bit_Array";

#load "rdg_view_registry.jai";
#load "rdg_resources.jai";
