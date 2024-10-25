
init_post_process_pipelines :: (bindless_set_layout: *RHIDescriptorSetLayout) {
    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .ALL_STAGES),
        rhi_bindless_descriptor_set_layout_binding(.RW_TEXTURE, 0, .ALL_STAGES),
    ];

    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{bindless_set_layout, used_bindless_bindings},
    ];

    pipeline_create_info: RHIComputePipelineCreateInfo;
    rhi_set_compute_shader(*pipeline_create_info, "tonemap_cs");
    rhi_set_pipeline_layout_desc(*pipeline_create_info, layout_decls, size_of(TonemapPushConsts), .COMPUTE_BIT, .[], 0);

    tonemap_pipeline = rhi_compute_pipeline_build(pipeline_create_info);
}

destroy_post_process_pipelines :: () {
    rhi_compute_pipeline_destroy(tonemap_pipeline);
}

render_post_process_pass :: (rg: *RenderGraph, view_data: *RenderViewData, color_texture_handle: RDGResourceViewHandle, lightmap_texture_handle: RDGResourceViewHandle) -> RDGResourceViewHandle {
    // tonemap and store result in the swapchain's image format
    tonemap_result_desc := RDGImageDescription.{
        debug_name = "Tonemap Result",
        width = swapchain.extent.width,
        height = swapchain.extent.height,
        format = swapchain.format,
        usage_flags = .RW_TEXTURE_BIT | .TEXTURE_BIT,
    };

    tonemap_result_handle := rdg_create_image(rg, tonemap_result_desc);
    tonemap_view_handle := rdg_create_image_view(rg, tonemap_result_handle, "Tonemap Result View");

    tonemap_pass_usage_descs := RDGResourceUsageDesc.[
        .{color_texture_handle, .{.READ_RESOURCE, .COMPUTE_SHADER_BIT}, .{}},
        .{lightmap_texture_handle, .{.READ_RESOURCE, .COMPUTE_SHADER_BIT}, .{}},
        .{tonemap_view_handle, .{.RW_RESOURCE_WRITE_ONLY, .COMPUTE_SHADER_BIT }, .{}}
    ];

    TonemapPassData :: struct {
        input_color_image: RDGResourceViewHandle;
        lightmap_texture: RDGResourceViewHandle;
        output_image: RDGResourceViewHandle;
        view_data: *RenderViewData;
    }

    tonemap_data := rdg_allocate_pass_data(rg, TonemapPassData);
    tonemap_data.input_color_image = color_texture_handle;
    tonemap_data.lightmap_texture = lightmap_texture_handle;
    tonemap_data.output_image = tonemap_view_handle;
    tonemap_data.view_data = view_data;

    rdg_add_pass(rg, "Tonemap", .GRAPHICS, tonemap_pass_usage_descs, tonemap_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
        pass_data := cast(*TonemapPassData) pass_data_ptr;
        rhi_cmd_bind_pipeline(cmd_list, tonemap_pipeline);

        rhi_cmd_bind_descriptor_sets(cmd_list, tonemap_pipeline, 0, .[pass_data.view_data.bindless_set], .[]);

        width := swapchain.extent.width;
        height := swapchain.extent.height;

        push_consts: TonemapPushConsts;
        push_consts.resolution[0] = width;
        push_consts.resolution[1] = height;
        push_consts.texel_size[0] = 1. / width;
        push_consts.texel_size[1] = 1. / height;
        push_consts.input_color_image_index = rdg_get_bindless_handle(pass_data.input_color_image, .TEXTURE);
        push_consts.lightmap_texture = rdg_get_bindless_handle(pass_data.lightmap_texture, .TEXTURE);
        push_consts.output_image_index = rdg_get_bindless_handle(pass_data.output_image, .RW_TEXTURE);

        rhi_cmd_push_constants(cmd_list, tonemap_pipeline, .COMPUTE_BIT, 0, size_of(TonemapPushConsts), *push_consts);
        rhi_cmd_dispatch(cmd_list, (width + 7) / 8, (height + 7) / 8, 1);
    });

    return tonemap_view_handle;
}

#scope_file

TonemapPushConsts :: struct {
    resolution: [2] u32;
    texel_size: [2] float;

    input_color_image_index: u32;
    lightmap_texture: u32;
    output_image_index: u32;
}

tonemap_pipeline: RHIComputePipeline;