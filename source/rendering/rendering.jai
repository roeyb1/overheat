#scope_export

Sprite :: struct {
    sheet: *SpriteSheet = null;
    scale: Vector2 = .{1, 1};
    index: u32 = 0;
    z_order: u16 = 0;
}

// Copy over the sprite data required for rendering so we don't need to directly reference it
Sprite_Draw_Cmd :: struct {
    sheet: *SpriteSheet;

    sprite_index: u32;
    z_order: u16;

    position: Vector2;
    scale: Vector2;
}

rendering_init :: () -> bool {
    log("Initialized rendering systems...");

    init_rhi();
    init_surface();
    init_device();
    rhi_swapchain_init(xx g_window_width, xx g_window_height);

    rdg_initialize(*g_render_graph);
    rdg_init_view_registry(*g_view_registry);
    init_texture_manager();

    init_rendering_resources();

    log("Rendering systems initialized successfully");
    return true;
}

rendering_shutdown :: () {
    rhi_device_wait_idle();

    destroy_rendering_resources();

    destroy_texture_manager();

    rdg_destroy_view_registry(*g_view_registry);
    rdg_shutdown(*g_render_graph);

    rhi_swapchain_destroy();
    destroy_device();
    destroy_surface();
    destroy_rhi();

    log("Rendering systems shutdown successfully");
}

rendering_begin_frame :: () {
    if g_window_resized_this_frame {
        rhi_swapchain_resize(xx g_window_width, xx g_window_height, acquire_image = true);
    }

    rhi_swapchain_image_index();
}

rendering_end_frame :: () {
    g_window_resized_this_frame = false;
}

DrawBucket :: struct {
    start: u64;
    count: u64;
    sprite_sheet: *SpriteSheet;
}


// generic rendering resources:

// global command pool/list to submit one time commands. Must be reset before use!
g_single_use_cmd_pool: RHICmdPool;
g_single_use_cmd_list: RHICmdList;

quad_vertex_buffer: *RHIBuffer;

constant_buffers: [RDG_NUM_FRAMES] *RHIBuffer;
constant_buff_linear_allocs: [RDG_NUM_FRAMES] RHILinearGPUAllocator;

vertex_buffers: [RDG_NUM_FRAMES] *RHIBuffer;
vertex_buffer_allocators: [RDG_NUM_FRAMES] RHILinearGPUAllocator;

index_buffers: [RDG_NUM_FRAMES] *RHIBuffer;
index_buffer_allocators: [RDG_NUM_FRAMES] RHILinearGPUAllocator;

offset_buffer_descriptor_set_layout: RHIDescriptorSetLayout;
offset_buffer_descriptor_pool: RHIDescriptorPool;
offset_buffer_descriptor_sets: [RDG_NUM_FRAMES] RHIDescriptorSet;

imgui_font_texture: *RHIImage;
imgui_font_texture_view: *RHIImageView;
imgui_font_texture_view_handle: RDGTextureViewHandle;

RenderViewData :: struct {
    scene_texture_size: Extent2D;

    camera_proj: Matrix4;
    camera_position: Vector3;

    bindless_set: *RHIDescriptorSet;
    offset_buffer_set: *RHIDescriptorSet;

    constant_buffer_allocator: *RHILinearGPUAllocator;
    vertex_buffer_allocator: *RHILinearGPUAllocator;
    index_buffer_allocator: *RHILinearGPUAllocator;
}

render_scene :: (view_proj: Matrix4, view_pos: Vector2) {
    rg := *g_render_graph;
    frame_number := rdg_next_frame(rg);
    resource_index := frame_number % RDG_NUM_FRAMES;

    rhi_reset(*constant_buff_linear_allocs[resource_index]);
    rhi_reset(*vertex_buffer_allocators[resource_index]);
    rhi_reset(*index_buffer_allocators[resource_index]);

    view_data := init_view_data_for_frame(rg, view_proj, view_pos, resource_index);

    texture_manager_flush_deletions();

    rdg_add_pass(rg, "Flush Uploads", .GRAPHICS, .[], null, (cmd_list: *RHICmdList, pass_data: *void) -> () {
        texture_loader_flush_uploads(cmd_list);
    });

    render_image_desc := RDGImageDescription.{
        debug_name = "Render Image",
        width = swapchain.extent.width,
        height = swapchain.extent.height,
        format = .B8G8R8A8_UNORM,
        usage_flags = .COLOR_ATTACHMENT_BIT | .TEXTURE_BIT | .RW_TEXTURE_BIT | . TRANSFER_SRC_BIT,
    };

    // render sprites
    sprite_color_image_view := render_sprite_pass(rg, *view_data);


    lightmap_image_view: RDGResourceViewHandle;
    {
        lightmap_image_desc := RDGImageDescription.{
            debug_name = "Lightmap Buffer",
            width = view_data.scene_texture_size.width,
            height = view_data.scene_texture_size.height,
            format = .R16G16B16A16_SFLOAT,
            usage_flags = .COLOR_ATTACHMENT_BIT,
        };
        lightmap_image_desc.clear_value.color._float32 = .[0, 0, 0, 1.];

        lightmap_image_handle := rdg_create_image(rg, lightmap_image_desc);
        lightmap_image_view = rdg_create_image_view(rg, lightmap_image_handle, "Lightmap Buffer View");

        render_light_passes(rg, *view_data, lightmap_image_view);
    }

    // render post process
    tonemap_result_image_view := render_post_process_pass(rg, *view_data, sprite_color_image_view, lightmap_image_view);

    render_imgui_pass(rg, *view_data, tonemap_result_image_view);

    // present to swapchain:
    {
        swapchain_index := swapchain.current_image_index;
        swapchain_image_handle := rdg_import_image(rg, *swapchain.images[swapchain_index], "Swapchain Image");
        swapchain_view_handle := rdg_create_image_view(rg, swapchain_image_handle, "Swapchain Image View");


        // copy render image to swapchain image:
        {
            usage_descs: [2] RDGResourceUsageDesc;
            usage_descs[0] = RDGResourceUsageDesc.{view_handle = tonemap_result_image_view, state_and_stage = .{resource_state = .READ_TRANSFER}};
            usage_descs[1] = RDGResourceUsageDesc.{view_handle = swapchain_view_handle, state_and_stage = .{resource_state = .WRITE_TRANSFER}};

            PassData :: struct {
                color_view_handle: RDGResourceViewHandle;
                swapchain_view_handle: RDGResourceViewHandle;
            };

            pass_data := rdg_allocate_pass_data(rg, PassData);
            pass_data.color_view_handle = tonemap_result_image_view;
            pass_data.swapchain_view_handle = swapchain_view_handle;

            rdg_add_pass(rg, "Copy to Swapchain", .GRAPHICS, usage_descs, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
                pass_data := cast(*PassData) pass_data_ptr;
                render_image_view := pass_data.color_view_handle;
                swapchain_image_view := pass_data.swapchain_view_handle;

                image_copies := RHIImageCopy.[.{
                    src_layer_count = 1,
                    dst_layer_count = 1,
                    extent = .{swapchain.extent.width, swapchain.extent.height, 1},
                }];

                rhi_cmd_copy_image(cmd_list, rdg_get_image(render_image_view), rdg_get_image(swapchain_image_view), image_copies);
            });
        }

        {
            present_transition_usages := RDGResourceUsageDesc.{
                swapchain_view_handle,
                .{ resource_state = RHIResourceState.PRESENT },
                .{},
            };

            rdg_add_pass(rg, "Present Transition", .GRAPHICS, .[present_transition_usages], null, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
                rhi_cmd_debug_label_insert(cmd_list, "Present");
            });
        }
    }

    rdg_flush_resource_view_updates(*g_view_registry);
    rdg_execute(rg);


    rhi_swapchain_present(rg.semaphores[RHIQueueIndex.GRAPHICS].handle, rg.semaphore_values[RHIQueueIndex.GRAPHICS], rg.semaphores[RHIQueueIndex.GRAPHICS].handle, rg.semaphore_values[RHIQueueIndex.GRAPHICS] + 1);
    rg.semaphore_values[RHIQueueIndex.GRAPHICS] += 1;

    rdg_swap_sets(*g_view_registry);
}

render_light_passes :: (rg: *RenderGraph, view_data: *RenderViewData, lightmap_texture_view: RDGResourceViewHandle) {
    for Query(Position, Point_Light).{world = *g_world} {
        render_shadowmap_pass(rg, view_data, lightmap_texture_view, it.position);
        render_lightmap_pass(rg, view_data, lightmap_texture_view, it.position, it.point_light);
    }
}

init_view_data_for_frame :: (rg: *RenderGraph, view_proj: Matrix4, view_pos: Vector2, resource_index: u64) -> RenderViewData {
    view_data := RenderViewData.{
        scene_texture_size = swapchain.extent,
        bindless_set = *g_view_registry.descriptor_sets[g_view_registry.frame_index % RDG_NUM_FRAMES],
        offset_buffer_set = *offset_buffer_descriptor_sets[resource_index],
        constant_buffer_allocator = *constant_buff_linear_allocs[resource_index],
        vertex_buffer_allocator = *vertex_buffer_allocators[resource_index],
        index_buffer_allocator = *index_buffer_allocators[resource_index],

        camera_proj = view_proj,
        camera_position = make_vector3(view_pos, 1.),
    };

    return view_data;
}

init_rendering_resources :: () {
    // single time command buffers:
    {
        g_single_use_cmd_pool = rhi_cmd_pool_create(rhi_queues[RHIQueueType.GRAPHICS]);
        g_single_use_cmd_list = rhi_cmd_list_allocate(g_single_use_cmd_pool);
    }

    // constant buffers:
    {
        create_info := RHIBufferCreateInfo.{
            size = 1024 * 1024 * 4,
            usage_flags = .CONSTANT_BUFFER_BIT,
            create_flags = 0,
        };

        constant_buffers[0] = rhi_buffer_create(create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, .DEVICE_LOCAL_BIT, false);
        constant_buffers[1] = rhi_buffer_create(create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, .DEVICE_LOCAL_BIT, false);
        rhi_debug_set_object_name(constant_buffers[0], "Constant Buffer 0");
        rhi_debug_set_object_name(constant_buffers[0], "Constant Buffer 1");

        constant_buff_linear_allocs[0] = rhi_linear_allocator_init(constant_buffers[0]);
        constant_buff_linear_allocs[1] = rhi_linear_allocator_init(constant_buffers[1]);

        binding := RHIDescriptorSetLayoutBinding.{
            descriptor_type = .OFFSET_CONSTANT_BUFFER,
            binding = 0, space = 0, descriptor_count = 1,
            stage_flags = .ALL_STAGES,
        };

        offset_buffer_descriptor_set_layout = rhi_descriptor_set_layout_create(.[binding]);
        offset_buffer_descriptor_pool = rhi_descriptor_pool_create(RDG_NUM_FRAMES, *offset_buffer_descriptor_set_layout);
        rhi_descriptor_set_allocate(*offset_buffer_descriptor_pool, RDG_NUM_FRAMES, offset_buffer_descriptor_sets);

        for 0..RDG_NUM_FRAMES-1 {
            update := RHIDescriptorSetUpdate.{
                dst_binding = 0, dst_array_element = 0, descriptor_count = 1,
                descriptor_type = .OFFSET_CONSTANT_BUFFER
            };

            update.buffer_info = RHIDescriptorBufferInfo.{
                buffer = constant_buffers[it],
                offset = 0,
                range = constant_buffers[it].desc.size,
                structure_byte_stride = 0,
            };

            rhi_descriptor_set_update(offset_buffer_descriptor_sets[it], .[update]);
        }
    }

    // vertex buffers: 
    {
        create_info := RHIBufferCreateInfo.{
            size = 1024 * 1024 * 4, // is this enough?
            usage_flags = .VERTEX_BUFFER_BIT,
        };

        vertex_buffers[0] = rhi_buffer_create(create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, .DEVICE_LOCAL_BIT, false);
        vertex_buffers[1] = rhi_buffer_create(create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, .DEVICE_LOCAL_BIT, false);
        rhi_debug_set_object_name(vertex_buffers[0], "Vertex Buffer 0");
        rhi_debug_set_object_name(vertex_buffers[1], "Vertex Buffer 1");
        
        vertex_buffer_allocators[0] = rhi_linear_allocator_init(vertex_buffers[0]);
        vertex_buffer_allocators[1] = rhi_linear_allocator_init(vertex_buffers[1]);
    }

    // index buffers:
    {
        create_info := RHIBufferCreateInfo.{
            size = 1024 * 1024 * 4,
            usage_flags = .INDEX_BUFFER_BIT,
        };

        index_buffers[0] = rhi_buffer_create(create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, .DEVICE_LOCAL_BIT, false);
        index_buffers[1] = rhi_buffer_create(create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, .DEVICE_LOCAL_BIT, false);
        rhi_debug_set_object_name(index_buffers[0], "Index Buffer 0");
        rhi_debug_set_object_name(index_buffers[1], "Index Buffer 1");

        index_buffer_allocators[0] = rhi_linear_allocator_init(index_buffers[0]);
        index_buffer_allocators[1] = rhi_linear_allocator_init(index_buffers[1]);
    }

    // imgui foint texture
    {
        io := ImGui.GetIO();

        pixels: *u8 = null;
        width: s32;
        height: s32;

        io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);
        upload_size: u64 = cast(u64)(width * height * 4);

        staging_create_info := RHIBufferCreateInfo.{
            size = upload_size,
            usage_flags = .TRANSFER_SRC_BIT,
        };
        staging_buffer := rhi_buffer_create(staging_create_info, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT, 0, false);

        image_create_info := RHIImageCreateInfo.{
            extent = .{ xx width, xx height },
            depth = 1,
            levels = 1,
            layers = 1,
            samples = ._1,
            image_type = ._2D,
            format = .R8G8B8A8_UNORM,
            usage_flags = .TRANSFER_DST_BIT | .TEXTURE_BIT,
        };
        imgui_font_texture = rhi_image_create(image_create_info, .DEVICE_LOCAL_BIT, 0, false);
        rhi_debug_set_object_name(imgui_font_texture, "ImGui Font Texture");

        imgui_font_texture_view = rhi_image_view_create(imgui_font_texture);

        imgui_font_texture_view_handle = rdg_create_texture_view_handle(*g_view_registry, imgui_font_texture_view);

        mapped_ptr := rhi_buffer_map(staging_buffer);
        {
            memcpy(mapped_ptr, pixels, cast(s64) upload_size);
        }
        rhi_buffer_unmap(staging_buffer);

        rhi_cmd_pool_reset(g_single_use_cmd_pool);
        cmd_list := *g_single_use_cmd_list;
        rhi_cmd_list_begin(cmd_list);
        {
            barrier := RHIBarrier.{
                image = imgui_font_texture,
                stages_before = .HOST_BIT,
                stages_after = .TRANSFER_BIT,
                state_before = .UNDEFINED,
                state_after = .WRITE_TRANSFER,
                image_subresource_range = .{0, 1, 0, 1},
            };

            rhi_cmd_barrier(cmd_list, .[barrier]);


            buffer_copy := RHIBufferImageCopy.{
                buffer_offset = 0,
                buffer_row_length = 0,
                buffer_image_height = 0,
                image_mip_level = 0,
                image_base_layer = 0,
                image_layer_count = 1,
                offset = .{0, 0, 0},
                extent = .{xx width, xx height, 1},
            };
            
            rhi_cmd_copy_buffer_to_image(cmd_list, staging_buffer, imgui_font_texture, .[buffer_copy]);

            barrier = RHIBarrier.{
                image = imgui_font_texture,
                stages_before = .TRANSFER_BIT,
                stages_after = .PIXEL_SHADER_BIT,
                state_before = .WRITE_TRANSFER,
                state_after = .READ_RESOURCE,
                image_subresource_range = .{0, 1, 0, 1},
            };

            rhi_cmd_barrier(cmd_list, .[barrier]);
        }

        rhi_cmd_list_end(cmd_list);
        rhi_submit_single_time_commands(*rhi_queues[RHIQueueType.GRAPHICS], cmd_list);

        rhi_buffer_destroy(staging_buffer);

        io.Fonts.TexID = cast(ImGui.ImTextureID)imgui_font_texture_view_handle;
    }


    init_sprite_pipeline(*offset_buffer_descriptor_set_layout, *g_view_registry.descriptor_set_layout);
    init_shadowmap_pipeline(*offset_buffer_descriptor_set_layout, *g_view_registry.descriptor_set_layout);
    init_lightmap_pipeline(*offset_buffer_descriptor_set_layout, *g_view_registry.descriptor_set_layout);
    init_post_process_pipelines(*g_view_registry.descriptor_set_layout);
    init_imgui_pipeline(*offset_buffer_descriptor_set_layout, *g_view_registry.descriptor_set_layout);
}

destroy_rendering_resources :: () {
    rhi_image_view_destroy(imgui_font_texture_view);
    rhi_image_destroy(imgui_font_texture);

    rhi_cmd_pool_destroy(g_single_use_cmd_pool);

    rhi_descriptor_pool_reset(*offset_buffer_descriptor_pool);
    rhi_descriptor_pool_destroy(offset_buffer_descriptor_pool);
    rhi_descriptor_set_layout_destroy(offset_buffer_descriptor_set_layout);

    destroy_imgui_pipeline();
    destroy_post_process_pipelines();
    destroy_lightmap_pipeline();
    destroy_shadowmap_pipeline();
    destroy_sprite_pipeline();

    for 0..RDG_NUM_FRAMES-1 {
        rhi_linear_allocator_destroy(*constant_buff_linear_allocs[it]);
        rhi_buffer_destroy(constant_buffers[it]);

        rhi_linear_allocator_destroy(*vertex_buffer_allocators[it]);
        rhi_buffer_destroy(vertex_buffers[it]);

        rhi_linear_allocator_destroy(*index_buffer_allocators[it]);
        rhi_buffer_destroy(index_buffers[it]);
    }

    texture_loader_destroy();
}

#scope_file

#load "../rhi/rhi.jai";
#load "render_graph.jai";
#load "texture_loader.jai";
#load "texture_manager.jai";
#load "sprite_rendering.jai";
#load "post_process.jai";
#load "imgui_rendering.jai";
#load "shadowmap_rendering.jai";
#load "lightmap_rendering.jai";

#import "Sort";
#import "File";

#if OS == .WINDOWS {
    #import "Windows";
}
