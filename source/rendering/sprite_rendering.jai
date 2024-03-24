#scope_export

sprite_pipeline: RHIGraphicsPipeline;

SpritePushConst :: struct {
    spritesheet_index: u32;
}

init_sprite_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    render_target_formats := RHIFormat.[
        .R16G16B16A16_SFLOAT,
    ];

    blend_states := RHIPipelineColorBlendAttachmentState.[
        RHIPipelineColorBlendAttachmentState.{}
    ];

    // #todo: maybe automate creation of attributes directly from vertex struct members
    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "VERTEX_POSITION", 0, 0, .R32G32B32_SFLOAT, 0},
        .{ "TEXCOORD", 1, 1, .R32G32_SFLOAT, 0},
        .{ "INSTANCE_POS", 2, 2, .R32G32B32_SFLOAT, 0},
        .{ "INSTANCE_SCALE", 3, 3, .R32G32_SFLOAT, 0},
        .{ "SPRITE_INDEX", 4, 4, .R32_UINT, 0},
    ];

    binding_descs := RHIVertexInputBindingDesc.[
        .{0, size_of(float) * 3, .VERTEX },
        .{1, size_of(float) * 2, .VERTEX },
        .{2, size_of(float) * 3, .INSTANCE },
        .{3, size_of(float) * 2, .INSTANCE },
        .{4, size_of(u32) * 1, .INSTANCE },
    ];


    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "sprite_vs");
    rhi_set_pixel_shader(*create_info, "sprite_ps");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, true, true, .EQUAL); // #todo: disable depth write if we ever implement a depth prepass
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_depth_stencil_attachment_format(*create_info, .D32_SFLOAT);
    rhi_set_color_attachment_formats(*create_info, render_target_formats);

    used_offset_buffer_binding := RHIDescriptorSetLayoutBinding.[.{
        descriptor_type = .OFFSET_CONSTANT_BUFFER,
        binding = 0,
        space = 0,
        descriptor_count = 1,
        stage_flags = .ALL_STAGES,
    }];

    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT), // spritesheet textures
    ];

    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{offset_buffer_set_layout, used_offset_buffer_binding },
        .{bindless_set_layout, used_bindless_bindings }
    ];

    static_samplers := RHIStaticSamplerDesc.[
        rhi_static_anisotropic_repeat_sampler(0, 0, .PIXEL_BIT),
    ];

    push_const_size: u32 = size_of(SpritePushConst);

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 2);
    
    sprite_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_sprite_pipeline :: () {
    rhi_graphics_pipeline_destroy(sprite_pipeline);
}


render_sprite_pass :: (rg: *RenderGraph) -> RDGResourceViewHandle {
    depth_image_desc := RDGImageDescription.{
        debug_name = "Sprite Depth Buffer",
        width = swapchain.extent.width,
        height = swapchain.extent.height,
        format = .D32_SFLOAT,
        usage_flags = .DEPTH_STENCIL_ATTACHMENT_BIT,
    };
    depth_image_handle := rdg_create_image(rg, depth_image_desc);
    depth_image_view := rdg_create_image_view(rg, depth_image_handle, "Sprite Depth Buffer View");

    color_image_desc := RDGImageDescription.{
        debug_name = "Sprite Color Buffer",
        width = swapchain.extent.width,
        height = swapchain.extent.height,
        format = .R8G8B8A8_SRGB,
        usage_flags = .COLOR_ATTACHMENT_BIT,
    };

    color_image_handle := rdg_create_image(rg, color_image_desc);
    color_image_view := rdg_create_image_view(rg, color_image_handle, "Sprite Color Buffer View");

    sprite_pass_usage_descs := RDGResourceUsageDesc.[
        .{depth_image_view, .{resource_state = .WRITE_DEPTH_STENCIL}, .{}},
        .{color_image_view, .{resource_state = .WRITE_COLOR_ATTACHMENT}, .{}},
    ];

    PassData :: struct {
        depth_image_view: RDGResourceViewHandle;
        color_image_view: RDGResourceViewHandle;
    };

    pass_data := rdg_allocate_pass_data(rg, PassData);
    pass_data.depth_image_view = depth_image_view;
    pass_data.color_image_view = color_image_view;

    rdg_add_pass(rg, "Sprite pass", .GRAPHICS, sprite_pass_usage_descs, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
        pass_data := cast(*PassData) pass_data_ptr;
        depth_image_view := pass_data.color_image_view;
        color_image_view := pass_data.depth_image_view;

        depth_buffer_desc := RHIDepthStencilAttachmentDesc.{
            image_view = rdg_get_image_view(depth_image_view),
            load_op = .CLEAR,
            store_op = .STORE,
            stencil_load_op = .DONT_CARE,
            stencil_store_op =.DONT_CARE,
        };

        
    });

    return color_image_view;
}