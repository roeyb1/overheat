
/** Point light is a component that can be added to an entity to make it render a as a radial, point source light light */
Point_Light :: struct {
    color: Vector3;
    radius: float;
    intensity: float;
}

AMBIENT_LIGHT :: float32.[0.5, 0.5, 0.5, 1.];

g_point_light_texture: TextureHandle;

init_lightmap_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    // Store lightmap data in a higher precision, non-linear format for higher dynamic range
    render_target_formats := RHIFormat.[
        .R16G16B16A16_SFLOAT,
    ];

    // Use additive blending to add all light sources together
    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = true,
            src_color_blend_factor = .DST_ALPHA,
            dst_color_blend_factor = .ONE,
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ZERO,
            dst_alpha_blend_factor = .ONE,
            alpha_blend_op = .ADD,
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "VERTEX_POSITION", 0, 0, .R32G32_SFLOAT, xx offset_of(Vertex2D, "pos")},
        .{ "TEXCOORD", 1, 0, .R32G32_SFLOAT, xx offset_of(Vertex2D, "uv")},
    ];

    binding_descs := RHIVertexInputBindingDesc.[
        .{0, size_of(Vertex2D), .VERTEX },
    ];


    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "lightmap_vs");
    rhi_set_pixel_shader(*create_info, "lightmap_ps");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_color_attachment_formats(*create_info, render_target_formats);

    used_offset_buffer_binding := RHIDescriptorSetLayoutBinding.[.{
        descriptor_type = .OFFSET_CONSTANT_BUFFER,
        binding = 0,
        space = 0,
        descriptor_count = 1,
        stage_flags = .ALL_STAGES,
    }];

    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT), // point light sprite
    ];

    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{offset_buffer_set_layout, used_offset_buffer_binding },
        .{bindless_set_layout, used_bindless_bindings }
    ];

    static_samplers := RHIStaticSamplerDesc.[
        rhi_static_point_clamp_sampler(0, 0, .PIXEL_BIT),
    ];

    push_const_size: u32 = size_of(Lightmap_Push_Const);

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .VERTEX_BIT | .PIXEL_BIT, static_samplers, 2);
    
    lightmap_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_lightmap_pipeline :: () {
    rhi_graphics_pipeline_destroy(lightmap_pipeline);
}

render_lightmap_pass :: (rg: *RenderGraph, view_data: *RenderViewData, lightmap_image_view: RDGResourceViewHandle, light_position: Position, point_light: Point_Light) {
    light_data := Point_Light_Data.{
        color = point_light.color,
        position = light_position,
        radius = point_light.radius,
        intensity = point_light.intensity,
    };

    lightmap_pass_usages := RDGResourceUsageDesc.[
        .{lightmap_image_view, .{resource_state = .WRITE_COLOR_ATTACHMENT}, .{}},
    ];

    pass_data := rdg_allocate_pass_data(rg, Lightmap_Pass_Data);
    pass_data.view_data = view_data;
    pass_data.light_data = light_data;
    pass_data.lightmap_image_view = lightmap_image_view;

    rdg_add_pass(rg, "Lightmap Pass", .GRAPHICS, lightmap_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
        pass_data := cast(*Lightmap_Pass_Data) pass_data_ptr;
        view_data := pass_data.view_data;

        vertex_buffer_offset: s64 = -1;
        index_buffer_offset: s64 = -1;
        {
            vertices := Vertex2D.[
                .{.{-0.5, -0.5}, .{0., 0.}},
                .{.{+0.5, -0.5}, .{1., 0.}},
                .{.{-0.5, +0.5}, .{0., 1.}},
                .{.{+0.5, +0.5}, .{1., 1.}},
            ];

            indices := u32.[
                0, 1, 3,
                0, 3, 2,
            ];

            vertex_dst:, vertex_buffer_offset = rhi_allocate(view_data.vertex_buffer_allocator, size_of(Vertex2D), size_of(Vertex2D) * vertices.count);
            index_dst:, index_buffer_offset = rhi_allocate(view_data.index_buffer_allocator, size_of(u32), size_of(u32) * indices.count);

            memcpy(vertex_dst, vertices.data, size_of(Vertex2D) * vertices.count);
            memcpy(index_dst, indices.data, size_of(u32) * indices.count);

            assert(vertex_buffer_offset != -1);
            assert(index_buffer_offset != -1);
        }


        lightmap_image_view := pass_data.lightmap_image_view;

        lightmap_buffer_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(lightmap_image_view),
            load_op = .LOAD,
            store_op = .STORE,
        };

        render_rect := RHIRect.{ .{0, 0}, .{view_data.scene_texture_size.width, view_data.scene_texture_size.height}};

        rhi_cmd_begin_renderpass(cmd_list, .[lightmap_buffer_desc], null, render_rect, true);
        {
            viewport := RHIViewport.{ 0, 0, cast(float) view_data.scene_texture_size.width, cast(float) view_data.scene_texture_size.height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{view_data.scene_texture_size.width, view_data.scene_texture_size.height}};

            rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
            rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

            PassConstants :: struct {
                view_projection_matrix: Matrix4;
                camera_position: Vector3;
            }
            pass_consts: PassConstants = ---;
            pass_consts.view_projection_matrix = view_data.camera_proj;
            pass_consts.camera_position = view_data.camera_position;

            pass_const_addr := rhi_upload_struct(pass_data.view_data.constant_buffer_allocator, .OFFSET_CONSTANT_BUFFER, pass_consts);

            rhi_cmd_bind_pipeline(cmd_list, *lightmap_pipeline);

            descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.offset_buffer_set, pass_data.view_data.bindless_set];
            rhi_cmd_bind_descriptor_sets(cmd_list, *lightmap_pipeline, 0, descriptor_sets, .[ xx pass_const_addr ]);
            
            rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[view_data.vertex_buffer_allocator.buffer], .[xx vertex_buffer_offset]);
            rhi_cmd_bind_index_buffer(cmd_list, view_data.index_buffer_allocator.buffer, xx index_buffer_offset, .UINT32);

            push_const: Lightmap_Push_Const = .{
                point_light_texture = cast(u32) get_texture_view_handle(g_point_light_texture),
                light_data = pass_data.light_data,
            };
            rhi_cmd_push_constants(cmd_list, *lightmap_pipeline, .VERTEX_BIT | .PIXEL_BIT, 0, size_of(Lightmap_Push_Const), *push_const);

            rhi_cmd_draw_indexed(cmd_list, 6, 1, 0, 0, 0);
        }

        rhi_cmd_end_renderpass(cmd_list);
    });
}

#scope_file

Lightmap_Pass_Data :: struct {
    view_data: *RenderViewData;
    light_data: Point_Light_Data;
    lightmap_image_view: RDGResourceViewHandle;
}

Point_Light_Data :: struct {
    color: Vector3;
    position: Vector2;
    radius: float;
    intensity: float;
}

Lightmap_Push_Const :: struct {
    using light_data: Point_Light_Data;

    point_light_texture: u32;
}

lightmap_pipeline: RHIGraphicsPipeline;
