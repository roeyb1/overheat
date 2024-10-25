init_apply_lighting_pipeline :: (bindless_set_layout: *RHIDescriptorSetLayout) {
    render_target_formats := RHIFormat.[
        .R16G16B16A16_SFLOAT,
    ];

    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = false,
            src_color_blend_factor = .ONE,
            dst_color_blend_factor = .ONE,
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ONE,
            dst_alpha_blend_factor = .ONE,
            alpha_blend_op = .ADD,
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[];

    binding_descs := RHIVertexInputBindingDesc.[];

    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT), // input tex
    ];

    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{bindless_set_layout, used_bindless_bindings }
    ];

    static_samplers := RHIStaticSamplerDesc.[
        rhi_static_linear_clamp_sampler(0, 0, .PIXEL_BIT),
    ];

    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "fullscreen_vs");
    rhi_set_pixel_shader(*create_info, "apply_lighting_ps");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_color_attachment_formats(*create_info, render_target_formats);

    push_const_size: u32 = size_of(Apply_Lighting_Push_Consts);

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 1);
    
    apply_lighting_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_apply_lighting_pipeline :: () {
    rhi_graphics_pipeline_destroy(apply_lighting_pipeline);
}

apply_lighting :: (rg: *RenderGraph, view_data: *RenderViewData, scene_color: RDGResourceViewHandle, lightmap: RDGResourceViewHandle) -> RDGResourceViewHandle {
    render_extent := Vector2.{ cast(float) view_data.scene_texture_size.width, cast(float) view_data.scene_texture_size.height };

    hdr_image_view: RDGResourceViewHandle;
    hdr_image_desc := RDGImageDescription.{
        debug_name = "HDR Image",
        width = xx render_extent.x,
        height = xx render_extent.y,
        format = .R16G16B16A16_SFLOAT,
        usage_flags = .COLOR_ATTACHMENT_BIT | .CLEAR_BIT,
    };

    hdr_image_handle := rdg_create_image(rg, hdr_image_desc);
    hdr_image_view = rdg_create_image_view(rg, hdr_image_handle, "HDR Image View");

    pass_data := rdg_allocate_pass_data(rg, Apply_Lighting_Pass_Data);
    pass_data.view_data = view_data;
    pass_data.hdr_image = hdr_image_view;
    pass_data.scene_color = scene_color;
    pass_data.lightmap = lightmap;

    rc_pass_usages := RDGResourceUsageDesc.[
        .{hdr_image_view,   .{resource_state = .WRITE_COLOR_ATTACHMENT, stage_mask = .PIXEL_SHADER_BIT}, .{}},
        .{scene_color,      .{resource_state = .READ_RESOURCE,          stage_mask = .PIXEL_SHADER_BIT}, .{}},
        .{lightmap,         .{resource_state = .READ_RESOURCE,          stage_mask = .PIXEL_SHADER_BIT}, .{}},
    ];
    
    rdg_add_pass(rg, "Apply Lighting", .GRAPHICS, rc_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
        pass_data := cast(*Apply_Lighting_Pass_Data) pass_data_ptr;
        view_data := pass_data.view_data;

        hdr_rt_buffer_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(pass_data.hdr_image),
            load_op = .CLEAR,
            store_op = .STORE,
        };

        render_rect := RHIRect.{ .{0, 0}, .{ xx view_data.scene_texture_size.width, xx view_data.scene_texture_size.height }};
        viewport := RHIViewport.{ 0, 0, xx view_data.scene_texture_size.width, xx view_data.scene_texture_size.height, 0., 1.};
        scissor := RHIRect.{.{0, 0}, .{ xx view_data.scene_texture_size.width, xx view_data.scene_texture_size.height }};

        rhi_cmd_begin_renderpass(cmd_list, .[hdr_rt_buffer_desc], null, render_rect, true);
        {
            rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
            rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

            rhi_cmd_bind_pipeline(cmd_list, *apply_lighting_pipeline);

            descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.bindless_set];
            rhi_cmd_bind_descriptor_sets(cmd_list, *apply_lighting_pipeline, 0, descriptor_sets, .[]);

            push_const: Apply_Lighting_Push_Consts = .{
                scene_color = rdg_get_bindless_handle(pass_data.scene_color, .TEXTURE),
                lightmap = rdg_get_bindless_handle(pass_data.lightmap, .TEXTURE),
            };
            rhi_cmd_push_constants(cmd_list, *apply_lighting_pipeline, .PIXEL_BIT, 0, size_of(Apply_Lighting_Push_Consts), *push_const);

            rhi_cmd_draw(cmd_list, 3, 1, 0, 0);
        }
        rhi_cmd_end_renderpass(cmd_list);
    });

    return hdr_image_view;
}

#scope_file

Apply_Lighting_Pass_Data :: struct {
    view_data: *RenderViewData;

    hdr_image: RDGResourceViewHandle;
    scene_color: RDGResourceViewHandle;
    lightmap: RDGResourceViewHandle;
}

Apply_Lighting_Push_Consts :: struct {
    scene_color: u32;
    lightmap: u32;
}

apply_lighting_pipeline: RHIGraphicsPipeline;
