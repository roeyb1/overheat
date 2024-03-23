#scope_export

sprite_pipeline: RHIGraphicsPipeline;

rhi_init_sprite_pipeline :: (bindless_set_layout: *RHIDescriptorSetLayout) {
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
    rhi_set_vertex_shader(*create_info, "sprite.vert");
    rhi_set_pixel_shader(*create_info, "sprite.frag");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, true, true, .EQUAL); // #todo: disable depth write if we ever implement a depth prepass
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_depth_stencil_attachment_format(*create_info, .D32_SFLOAT);
    rhi_set_color_attachment_formats(*create_info, render_target_formats);


    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT), // spritesheet textures
    ];

    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{bindless_set_layout, used_bindless_bindings }
    ];

    static_samplers := RHIStaticSamplerDesc.[
        rhi_static_anisotropic_repeat_sampler(0, 0, .PIXEL_BIT),
    ];

    push_const_size: u32 = 0;

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, 0, static_samplers, 1);
    
    sprite_pipeline = rhi_graphics_pipeline_build(create_info);
}