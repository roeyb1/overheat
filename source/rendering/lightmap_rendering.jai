
/** Point light is a component that can be added to an entity to make it render a as a radial, point source light light */
Point_Light :: struct {
    color: Vector4;
    radius: float;
    intensity: float;
}

AMBIENT_LIGHT :: float32.[0.5, 0.5, 0.5, 1.];

g_point_light_texture: TextureHandle;

init_lightmap_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    render_target_formats := RHIFormat.[
        .R16G16B16A16_SFLOAT,
    ];

    // Use additive blending to add all light sources together
    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = true,
            src_color_blend_factor = .ONE,
            dst_color_blend_factor = .ONE,
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ONE,
            dst_alpha_blend_factor = .ONE,
            alpha_blend_op = .ADD,
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "VERTEX_POSITION", 0, 0, .R32G32_SFLOAT, xx offset_of(Vertex2D, "pos")},
        .{ "TEXCOORD", 1, 0, .R32G32_SFLOAT, xx offset_of(Vertex2D, "uv")},
        .{ "COLOR", 2, 1, .R32G32B32A32_SFLOAT, xx offset_of(Point_Light_Data, "color")},
        .{ "INSTANCE_POS", 3, 1, .R32G32_SFLOAT, xx offset_of(Point_Light_Data, "position")},
        .{ "RADIUS", 4, 1, .R32_SFLOAT, xx offset_of(Point_Light_Data, "radius")},
        .{ "INTENSITY", 5, 1, .R32_SFLOAT, xx offset_of(Point_Light_Data, "intensity")},
    ];

    binding_descs := RHIVertexInputBindingDesc.[
        .{0, size_of(Vertex2D), .VERTEX },
        .{1, size_of(Point_Light_Data), .INSTANCE },
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

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 2);
    
    lightmap_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_lightmap_pipeline :: () {
    rhi_graphics_pipeline_destroy(lightmap_pipeline);
}

render_lightmap_pass :: (rg: *RenderGraph, view_data: *RenderViewData) -> RDGResourceViewHandle {
    point_lights: [..] Point_Light_Data;
    point_lights.allocator = temp;
    for Query(Point_Light, Position).{world = *g_world} {
        light_data := Point_Light_Data.{
            color = it.point_light.color,
            position = it.position,
            radius = it.point_light.radius,
            intensity = it.point_light.intensity,
        };
        array_add(*point_lights, light_data);
    }

    lightmap_image_desc := RDGImageDescription.{
        debug_name = "Lightmap Buffer",
        width = swapchain.extent.width,
        height = swapchain.extent.height,
        format = .R16G16B16A16_SFLOAT,
        usage_flags = .COLOR_ATTACHMENT_BIT,
    };
    lightmap_image_desc.clear_value.color._float32 = AMBIENT_LIGHT;

    lightmap_image_handle := rdg_create_image(rg, lightmap_image_desc);
    lightmap_image_view := rdg_create_image_view(rg, lightmap_image_handle, "Lightmap Buffer View");

    lightmap_pass_usages := RDGResourceUsageDesc.[
        .{lightmap_image_view, .{resource_state = .WRITE_COLOR_ATTACHMENT}, .{}},
    ];

    pass_data := rdg_allocate_pass_data(rg, Lightmap_Pass_Data);
    pass_data.view_data = view_data;
    pass_data.point_lights = point_lights;
    pass_data.lightmap_image_view = lightmap_image_view;

    rdg_add_pass(rg, "Lightmap Pass", .GRAPHICS, lightmap_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
        pass_data := cast(*Lightmap_Pass_Data) pass_data_ptr;
        view_data := pass_data.view_data;

        vertex_buffer_offset: s64 = -1;
        index_buffer_offset: s64 = -1;
        instance_buffer_offset: s64 = -1;
        if pass_data.point_lights.count > 0 {
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
            instance_dst:, instance_buffer_offset = rhi_allocate(view_data.vertex_buffer_allocator, size_of(Point_Light_Data), size_of(Point_Light_Data) * pass_data.point_lights.count);
            index_dst:, index_buffer_offset = rhi_allocate(view_data.index_buffer_allocator, size_of(u32), size_of(u32) * indices.count);

            memcpy(vertex_dst, vertices.data, size_of(Vertex2D) * vertices.count);
            memcpy(index_dst, indices.data, size_of(u32) * indices.count);
            memcpy(instance_dst, pass_data.point_lights.data, size_of(Point_Light_Data) * pass_data.point_lights.count);

            assert(vertex_buffer_offset != -1);
            assert(index_buffer_offset != -1);
            assert(instance_buffer_offset != -1);
        }


        lightmap_image_view := pass_data.lightmap_image_view;

        lightmap_buffer_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(lightmap_image_view),
            load_op = .CLEAR,
            store_op = .STORE,
        };
        lightmap_buffer_desc.clear_value._float32 = AMBIENT_LIGHT;

        render_rect := RHIRect.{ .{0, 0}, .{xx g_window_width, xx g_window_height}};

        rhi_cmd_begin_renderpass(cmd_list, .[lightmap_buffer_desc], null, render_rect, true);

        if pass_data.point_lights.count > 0 {
            viewport := RHIViewport.{ 0, 0, cast(float) g_window_width, cast(float) g_window_height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{xx g_window_width, xx g_window_height}};

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
            
            rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[view_data.vertex_buffer_allocator.buffer, view_data.vertex_buffer_allocator.buffer], .[xx vertex_buffer_offset, xx instance_buffer_offset]);
            rhi_cmd_bind_index_buffer(cmd_list, view_data.index_buffer_allocator.buffer, xx index_buffer_offset, .UINT32);

            push_const: Lightmap_Push_Const = .{
                point_light_texture = cast(u32) get_texture_view_handle(g_point_light_texture),
            };
            rhi_cmd_push_constants(cmd_list, *lightmap_pipeline, .PIXEL_BIT, 0, size_of(Lightmap_Push_Const), *push_const);

            rhi_cmd_draw_indexed(cmd_list, 6, xx pass_data.point_lights.count, 0, 0, 0);
        }

        rhi_cmd_end_renderpass(cmd_list);
    });

    return lightmap_image_view;
}

#scope_file

Point_Light_Data :: struct {
    color: Vector4;
    position: Vector2;
    radius: float;
    intensity: float;
}

Lightmap_Pass_Data :: struct {
    view_data: *RenderViewData;
    point_lights: [..] Point_Light_Data;
    lightmap_image_view: RDGResourceViewHandle;
}

Lightmap_Push_Const :: struct {
    point_light_texture: u32;
}

lightmap_pipeline: RHIGraphicsPipeline;
