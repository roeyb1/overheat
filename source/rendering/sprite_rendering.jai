#scope_file

sprite_pipeline: RHIGraphicsPipeline;

SpritePushConst :: struct {
    spritesheet_index: u32;
    extent: u32;
    // #todo: pass to shader to save on instructions
    //spritesheet_width: float;
    //spritesheet_height: float;
}

SpriteVertex :: struct {
    pos: Vector2;
    uv: Vector2;
}

SpriteInstanceData :: struct {
    instance_pos: Vector2;
    instance_scale: Vector2;
    sprite_index: u32;
}

#scope_export

init_sprite_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    render_target_formats := RHIFormat.[
        .R8G8B8A8_SRGB,
    ];

    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = true,
            src_color_blend_factor = .SRC_ALPHA,
            dst_color_blend_factor = .ONE_MINUS_SRC_ALPHA,
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ONE,
            dst_alpha_blend_factor = .ONE,
            alpha_blend_op = .ADD,
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "VERTEX_POSITION", 0, 0, .R32G32_SFLOAT, xx offset_of(SpriteVertex, "pos")},
        .{ "TEXCOORD", 1, 0, .R32G32_SFLOAT, xx offset_of(SpriteVertex, "uv")},
        .{ "INSTANCE_POS", 2, 1, .R32G32B32_SFLOAT, xx offset_of(SpriteInstanceData, "instance_pos")},
        .{ "INSTANCE_SCALE", 3, 1, .R32G32_SFLOAT, xx offset_of(SpriteInstanceData, "instance_scale")},
        .{ "SPRITE_INDEX", 4, 1, .R32_UINT, xx offset_of(SpriteInstanceData, "sprite_index")},
    ];

    binding_descs := RHIVertexInputBindingDesc.[
        .{0, size_of(SpriteVertex), .VERTEX },
        .{1, size_of(SpriteInstanceData), .INSTANCE },
    ];


    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "sprite_vs");
    rhi_set_pixel_shader(*create_info, "sprite_ps");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, true, true, .LESS_OR_EQUAL); // #todo: disable depth write if we ever implement a depth prepass
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
        rhi_static_point_clamp_sampler(0, 0, .PIXEL_BIT),
    ];

    push_const_size: u32 = size_of(SpritePushConst);

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 2);
    
    sprite_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_sprite_pipeline :: () {
    rhi_graphics_pipeline_destroy(sprite_pipeline);
}

SpritePassData :: struct {
    depth_image_view: RDGResourceViewHandle;
    color_image_view: RDGResourceViewHandle;

    instance_buffer: RDGResourceViewHandle;
    
    view_data: *RenderViewData;
    sprite_datas: [..] SpriteDrawData;
    buckets: [..] SpriteDrawBucket;
};

render_sprite_pass :: (rg: *RenderGraph, view_data: *RenderViewData) -> RDGResourceViewHandle {
    draws: [..] SpriteDrawData;
    draws.allocator = temp;
    buckets: [..] SpriteDrawBucket;
    buckets.allocator = temp;
    collect_sprite_draw_batches(*draws, *buckets);

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

    pass_data := rdg_allocate_pass_data(rg, SpritePassData);
    pass_data.depth_image_view = depth_image_view;
    pass_data.color_image_view = color_image_view;
    pass_data.view_data = view_data;
    array_copy(*pass_data.sprite_datas, draws);
    array_copy(*pass_data.buckets, buckets);

    rdg_add_pass(rg, "Sprite pass", .GRAPHICS, sprite_pass_usage_descs, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
        pass_data := cast(*SpritePassData) pass_data_ptr;
        view_data := pass_data.view_data;

        // upload sprite vertex buffers
        vertex_buffer_offset: s64 = -1;
        index_buffer_offset: s64 = -1;
        instance_buffer_offset: s64 = -1;
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
            instance_dst:, instance_buffer_offset = rhi_allocate(view_data.vertex_buffer_allocator, size_of(SpriteInstanceData), size_of(SpriteInstanceData) * pass_data.sprite_datas.count);
            index_dst:, index_buffer_offset = rhi_allocate(view_data.index_buffer_allocator, size_of(u32), size_of(u32) * indices.count);

            memcpy(vertex_dst, vertices.data, size_of(SpriteVertex) * vertices.count);
            memcpy(index_dst, indices.data, size_of(u32) * indices.count);

            instance_data: [..] SpriteInstanceData;
            instance_data.allocator = temp;
            array_reserve(*instance_data, pass_data.sprite_datas.count);
            for draw : pass_data.sprite_datas {
                array_add(*instance_data, SpriteInstanceData.{
                    instance_pos = draw.position,
                    instance_scale = draw.scale,
                    sprite_index = draw.sprite_index,
                });
            }
            memcpy(instance_dst, instance_data.data, size_of(SpriteInstanceData) * instance_data.count);
        }
        assert(vertex_buffer_offset != -1);
        assert(index_buffer_offset != -1);
        assert(instance_buffer_offset != -1);


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

        render_rect := RHIRect.{ .{0, 0}, .{xx g_window_width, xx g_window_height}};

        rhi_cmd_begin_renderpass(cmd_list, .[color_buffer_desc], *depth_buffer_desc, render_rect, true);
        {
            viewport := RHIViewport.{ 0, 0, cast(float) g_window_width, cast(float) g_window_height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{xx g_window_width, xx g_window_height}};

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
            
            rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[view_data.vertex_buffer_allocator.buffer, view_data.vertex_buffer_allocator.buffer], .[xx vertex_buffer_offset, xx instance_buffer_offset]);
            rhi_cmd_bind_index_buffer(cmd_list, view_data.index_buffer_allocator.buffer, xx index_buffer_offset, .UINT32);

            for *bucket : pass_data.buckets {
                push_const: SpritePushConst = .{
                    spritesheet_index = cast(u32) get_texture_view_handle(bucket.sprite_sheet.texture),
                    extent = bucket.sprite_sheet.extent,
                };
                rhi_cmd_push_constants(cmd_list, *sprite_pipeline, .PIXEL_BIT, 0, size_of(SpritePushConst), *push_const);
                rhi_cmd_draw_indexed(cmd_list, 6, xx bucket.count, 0, 0, xx bucket.start);
            }
        }
        rhi_cmd_end_renderpass(cmd_list);

        free(pass_data.buckets.data);
        free(pass_data.sprite_datas.data);
    });

    return color_image_view;
}

#scope_file 

SpriteDrawData :: struct {
    sheet: *SpriteSheet;
    sprite_index: u32;

    position: Vector2;
    scale: Vector2;

    z_order: u16;
}

SpriteDrawBucket :: struct { 
    start: u64;
    count: u64;
    sprite_sheet: *SpriteSheet;
}


collect_sprite_draw_batches :: (out_draws: *[..] SpriteDrawData, out_buckets: *[..] SpriteDrawBucket) {
    // #todo: automatically register all sprites instead of doing this by specific entity types:
    add_sprite_draw :: (out_draws: *[..] SpriteDrawData, sprite: Sprite, position: Vector2) {
        draw := SpriteDrawData.{
            position = position,
            sheet = sprite.sheet,
            scale = sprite.scale,
            sprite_index = sprite.index,
            z_order = sprite.z_order,
        };

        array_add(out_draws, draw);
    }

    // collect all the draws for this frame
    {
        // Draw a temporary background
        {
            ground_sprite: Sprite;
            ground_sprite.sheet = g_dungeon_tiles;
            ground_sprite.z_order = 0;
            ground_sprite.scale = .{1, 1};

            for x : -20..20 {
                for y : -20..20 {
                    ground_sprite.index = 256;
                    add_sprite_draw(out_draws, ground_sprite, .{ xx x, xx y});
                }
            }
        }

        // Draw sprites
        {
            for Query(Sprite, Position).{world = *g_world} {
                add_sprite_draw(out_draws, it.sprite, it.position);
            }
        }
    }

    // First sort the draw calls by z-order
    // then sort them by spritesheet so we can batch each call of a given sheet in the same instanced draw call:
    {
        sort_predicate :: (a: SpriteDrawData, b: SpriteDrawData) -> s64 {
            if a.z_order == b.z_order {
                return cast(s64) a.sheet - cast(s64) b.sheet;
            }
            return cast(s64) a.z_order - cast(s64) b.z_order;
        }

        quick_sort(<< out_draws, sort_predicate);
    }

    // sort the draws into buckets by spritesheet:
    {
        current_bucket: *SpriteDrawBucket = null;
        current_z_order: u16 = 0;
        for draw_cmd :  (<<out_draws) {
            // Since the draw commands are already sorted by spritesheet
            // we can assume that the moment we find a new spritesheet that doesn't match, we're starting a new bucket.
            if current_bucket == null || (draw_cmd.sheet != current_bucket.sprite_sheet) || (draw_cmd.z_order != current_z_order) {
                // first time this runs, current will be null
                if current_bucket != null {
                    current_bucket.count = cast(u64) it_index - current_bucket.count;
                }

                current_bucket = array_add(out_buckets);
                current_bucket.start = cast(u64) it_index;
                current_bucket.sprite_sheet = draw_cmd.sheet;
                current_z_order = draw_cmd.z_order;
            }
        }

        current_bucket.count = cast(u64) out_draws.count - current_bucket.start;
    }
}