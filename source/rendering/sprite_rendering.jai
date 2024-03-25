#scope_export

sprite_pipeline: RHIGraphicsPipeline;

SpritePushConst :: struct {
    spritesheet_index: u32;
    sprite_index: u32;
}

SpriteVertex :: struct {
    pos: Vector2;
    uv: Vector2;
}


init_sprite_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    render_target_formats := RHIFormat.[
        .R8G8B8A8_SRGB,
    ];

    blend_states := RHIPipelineColorBlendAttachmentState.[
        RHIPipelineColorBlendAttachmentState.{}
    ];

    // #todo: maybe automate creation of attributes directly from vertex struct members
    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "VERTEX_POSITION", 0, 0, .R32G32_SFLOAT, 0},
        .{ "TEXCOORD", 1, 0, .R32G32_SFLOAT, cast(u32) offset_of(SpriteVertex, "uv")},
        //.{ "INSTANCE_POS", 2, 2, .R32G32B32_SFLOAT, 0},
        //.{ "INSTANCE_SCALE", 3, 3, .R32G32_SFLOAT, 0},
        //.{ "SPRITE_INDEX", 4, 4, .R32_UINT, 0},
    ];

    binding_descs := RHIVertexInputBindingDesc.[
        .{0, size_of(float) * 4, .VERTEX },
        //.{1, size_of(float) * x, .INSTANCE },
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

render_sprite_pass :: (rg: *RenderGraph, view_data: *RenderViewData) -> RDGResourceViewHandle {
    draws: [..] SpriteDrawData;
    draws.allocator = temp;
    collect_sprite_draw_batches(*draws);

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

        instance_buffer: RDGResourceViewHandle;
        
        view_data: *RenderViewData;
        sprite_datas: [] SpriteDrawData;
    };

    pass_data := rdg_allocate_pass_data(rg, PassData);
    pass_data.depth_image_view = depth_image_view;
    pass_data.color_image_view = color_image_view;
    pass_data.view_data = view_data;
    pass_data.sprite_datas = draws;

    rdg_add_pass(rg, "Sprite pass", .GRAPHICS, sprite_pass_usage_descs, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
        pass_data := cast(*PassData) pass_data_ptr;
        view_data := pass_data.view_data;

        // upload sprite vertex buffers
        vertex_buffer_offset: s64 = -1;
        index_buffer_offset: s64 = -1;
        {
            vertices := SpriteVertex.[
                .{.{-0.5, -0.5}, .{0., 0.}},
                .{.{+0.5, -0.5}, .{1., 0.}},
                .{.{-0.5, +0.5}, .{0., 1.}},
                .{.{+0.5, +0.5}, .{1., 1.}},
            ];

            indices := u32.[
                0, 1, 3,
                0, 3, 2,
            ];

            vertex_dst:, vertex_buffer_offset = rhi_allocate(view_data.vertex_buffer_allocator, size_of(SpriteVertex), size_of(SpriteVertex) * vertices.count);
            index_dst:, index_buffer_offset = rhi_allocate(view_data.index_buffer_allocator, size_of(u32), size_of(u32) * indices.count);

            memcpy(vertex_dst, vertices.data, size_of(SpriteVertex) * vertices.count);
            memcpy(index_dst, indices.data, size_of(u32) * indices.count);
        }
        assert(vertex_buffer_offset != -1);
        assert(index_buffer_offset != -1);



        depth_image_view := pass_data.depth_image_view;
        color_image_view := pass_data.color_image_view;

        depth_buffer_desc := RHIDepthStencilAttachmentDesc.{
            image_view = rdg_get_image_view(depth_image_view),
            load_op = .CLEAR,
            store_op = .STORE,
            stencil_load_op = .DONT_CARE,
            stencil_store_op = .DONT_CARE,
        };

        color_buffer_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(color_image_view),
            load_op = .CLEAR,
            store_op = .STORE,
        };

        render_rect := RHIRect.{ .{0, 0}, .{g_window_width, g_window_height}};

        rhi_cmd_begin_renderpass(cmd_list, .[color_buffer_desc], *depth_buffer_desc, render_rect, true);
        {
            viewport := RHIViewport.{ 0, 0, cast(float) g_window_width, cast(float) g_window_height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{g_window_width, g_window_height}};

            rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
            rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

            PassConstants :: struct {
                view_projection_matrix: Matrix4;
                camera_position: Vector3;
            }
            pass_consts: PassConstants = ---;
            pass_consts.view_projection_matrix = pass_data.view_data.camera_proj;
            pass_consts.camera_position = pass_data.view_data.camera_position;

            pass_const_addr := rhi_upload_struct(pass_data.view_data.constant_buffer_allocator, .OFFSET_CONSTANT_BUFFER, pass_consts);

            rhi_cmd_bind_pipeline(cmd_list, *sprite_pipeline);

            descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.offset_buffer_set, pass_data.view_data.bindless_set];
            rhi_cmd_bind_descriptor_sets(cmd_list, *sprite_pipeline, 0, descriptor_sets, .[ xx pass_const_addr ]);
            
            rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[view_data.vertex_buffer_allocator.buffer], .[xx vertex_buffer_offset]);
            rhi_cmd_bind_index_buffer(cmd_list, view_data.index_buffer_allocator.buffer, xx index_buffer_offset, .UINT32);
            rhi_cmd_draw_indexed(cmd_list, 6, 1, 0, 0, 0);

            for *sprite_draw : pass_data.sprite_datas {

            }
        }
        rhi_cmd_end_renderpass(cmd_list);
    });

    return color_image_view;
}

#scope_file 

SpriteDrawData :: struct {
    sheet: *SpriteSheet;
    sprite_index: s32;

    z_order: s8;

    position: Vector2;
    scale: Vector2;
}


collect_sprite_draw_batches :: (out_draws: *[..] SpriteDrawData) {
    // #todo: automatically register all sprites instead of doing this by specific entity types:
    add_sprite_draw :: (out_draws: *[..] SpriteDrawData, sprite: Sprite, position: Vector2) {
        draw := SpriteDrawData.{
            position = position,
            sheet = sprite.sheet,
            z_order = sprite.z_order,
            scale = sprite.scale,
            sprite_index = sprite.index,
        };

        array_add(out_draws, draw);
    }

    {
        // Draw a temporary background
        {
            ground_sprite: Sprite;
            ground_sprite.sheet = g_dungeon_tiles;
            ground_sprite.z_order = -1;

            for x : -20..20 {
                for y : -20..20 {
                    ground_sprite.index = 256;
                    add_sprite_draw(out_draws, ground_sprite, .{ xx x, xx y});
                }
            }
        }

        // Draw players
        {
            for :Player_It g_world {
                add_sprite_draw(out_draws, it.sprite, it.position);
            }
        }
    }
}